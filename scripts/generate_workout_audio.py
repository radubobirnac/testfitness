#!/usr/bin/env python3
"""
OpenAI TTS Audio Generator for StrengthWave Boxing/Workout App

This script generates high-quality audio files using OpenAI's TTS API for
boxing combinations, workout timing, motivation, and instructions.

Usage:
    python generate_workout_audio.py --api-key YOUR_OPENAI_API_KEY

Features:
- Async batch processing for efficiency
- Organized file structure by category
- Clean filename generation with hash suffixes
- Metadata tracking and cost estimation
- Auto-generated Dart integration code
- Rate limiting and error handling
"""

import asyncio
import hashlib
import json
import os
import re
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import argparse
import sys

try:
    import aiohttp
    import aiofiles
except ImportError:
    print("Missing required packages. Install with:")
    print("pip install aiohttp aiofiles")
    sys.exit(1)


class OpenAITTSGenerator:
    """OpenAI TTS API client for generating workout audio files."""

    def __init__(self, api_key: str, output_dir: str = "assets/audio/workout"):
        self.api_key = api_key
        self.output_dir = Path(output_dir)
        self.base_url = "https://api.openai.com/v1/audio/speech"
        self.session: Optional[aiohttp.ClientSession] = None

        # Audio settings - DRILL INSTRUCTOR ENERGY!
        self.model = "tts-1-hd"  # High quality model (will try gpt-4o-mini-tts if available)
        self.voice = "onyx"      # Deep, commanding male voice - DRILL INSTRUCTOR STYLE
        self.format = "mp3"      # Efficient format for mobile

        # Rate limiting
        self.max_concurrent = 5
        self.delay_between_requests = 0.2  # 200ms delay

        # Cost tracking
        self.total_characters = 0
        self.cost_per_1k_chars = 0.015  # TTS-1-HD pricing

        # Generated files tracking
        self.generated_files: Dict[str, List[Dict]] = {}

    async def __aenter__(self):
        """Async context manager entry."""
        self.session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=30),
            headers={"Authorization": f"Bearer {self.api_key}"}
        )
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        if self.session:
            await self.session.close()

    def setup_directories(self):
        """Create output directory structure."""
        categories = ["rounds", "timing", "motivation", "instructions", "rest", "combinations"]

        for category in categories:
            category_dir = self.output_dir / category
            category_dir.mkdir(parents=True, exist_ok=True)
            print(f"✓ Created directory: {category_dir}")

    def generate_filename(self, text: str, category: str) -> str:
        """Generate clean filename with hash suffix."""
        # Clean text for filename
        clean_text = re.sub(r'[^\w\s-]', '', text.lower())
        clean_text = re.sub(r'\s+', '_', clean_text.strip())
        clean_text = clean_text[:30]  # Limit length

        # Generate hash for uniqueness
        text_hash = hashlib.md5(text.encode()).hexdigest()[:8]

        return f"{clean_text}_{text_hash}.{self.format}"

    async def generate_audio(self, text: str, category: str) -> Optional[Dict]:
        """Generate single audio file from text."""
        if not self.session:
            raise RuntimeError("Session not initialized")

        filename = self.generate_filename(text, category)
        filepath = self.output_dir / category / filename

        # Skip if file already exists
        if filepath.exists():
            print(f"⏭️  Skipping existing: {filename}")
            return {
                "text": text,
                "filename": filename,
                "filepath": str(filepath),
                "category": category,
                "skipped": True
            }

        # Try gpt-4o-mini-tts first, fallback to tts-1-hd
        models_to_try = ["gpt-4o-mini-tts", "tts-1-hd"]

        for model_attempt, model in enumerate(models_to_try):
            # Make the voice sound like a FAST drill instructor
            drill_instructor_text = f"[Speaking quickly and commandingly like a drill instructor] {text}"

            payload = {
                "model": model,
                "input": drill_instructor_text,
                "voice": self.voice,
                "response_format": self.format,
                "speed": 1.25  # 25% faster for drill instructor pace
            }

            try:
                print(f"🎵 Generating with {model}: {text[:50]}...")

                async with self.session.post(self.base_url, json=payload) as response:
                    if response.status == 200:
                        audio_data = await response.read()

                        async with aiofiles.open(filepath, 'wb') as f:
                            await f.write(audio_data)

                        # Update tracking
                        self.total_characters += len(text)

                        print(f"✅ Generated with {model}: {filename}")

                        return {
                            "text": text,
                            "filename": filename,
                            "filepath": str(filepath),
                            "category": category,
                            "characters": len(text),
                            "model_used": model,
                            "skipped": False
                        }
                    else:
                        error_text = await response.text()
                        print(f"❌ Error with {model}: {response.status} - {error_text}")
                        if model_attempt == len(models_to_try) - 1:  # Last model attempt
                            return None
                        else:
                            print(f"🔄 Trying fallback model...")
                            continue

            except Exception as e:
                print(f"❌ Exception with {model}: {e}")
                if model_attempt == len(models_to_try) - 1:  # Last model attempt
                    return None
                else:
                    print(f"🔄 Trying fallback model...")
                    continue

        # If we get here, all models failed
        # Rate limiting delay
        await asyncio.sleep(self.delay_between_requests)
        return None

    async def generate_batch(self, texts_by_category: Dict[str, List[str]]) -> Dict[str, List[Dict]]:
        """Generate all audio files in batches."""
        print(f"🚀 Starting batch generation with {self.max_concurrent} concurrent requests...")

        # Create semaphore for rate limiting
        semaphore = asyncio.Semaphore(self.max_concurrent)

        async def generate_with_semaphore(text: str, category: str):
            async with semaphore:
                return await self.generate_audio(text, category)

        # Create all tasks
        tasks = []
        for category, texts in texts_by_category.items():
            for text in texts:
                task = generate_with_semaphore(text, category)
                tasks.append(task)

        # Execute all tasks
        results = await asyncio.gather(*tasks, return_exceptions=True)

        # Organize results by category
        organized_results = {}
        task_index = 0

        for category, texts in texts_by_category.items():
            organized_results[category] = []
            for _ in texts:
                result = results[task_index]
                if isinstance(result, dict):
                    organized_results[category].append(result)
                task_index += 1

        self.generated_files = organized_results
        return organized_results

    def estimate_cost(self, texts_by_category: Dict[str, List[str]]) -> float:
        """Estimate generation cost."""
        total_chars = sum(
            sum(len(text) for text in texts)
            for texts in texts_by_category.values()
        )
        return (total_chars / 1000) * self.cost_per_1k_chars

    def save_metadata(self):
        """Save generation metadata to JSON file."""
        metadata = {
            "generation_timestamp": time.time(),
            "generation_date": time.strftime("%Y-%m-%d %H:%M:%S"),
            "model": self.model,
            "voice": self.voice,
            "format": self.format,
            "total_characters": self.total_characters,
            "estimated_cost": (self.total_characters / 1000) * self.cost_per_1k_chars,
            "files_by_category": self.generated_files,
            "total_files": sum(len(files) for files in self.generated_files.values())
        }

        metadata_path = self.output_dir / "metadata.json"
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)

        print(f"💾 Saved metadata to: {metadata_path}")
        return metadata


def get_workout_texts() -> Dict[str, List[str]]:
    """Define all workout texts to generate, organized by category."""

    return {
        "rounds": [
            "ROUND ONE! MOVE IT MOVE IT!",
            "ROUND TWO! HUSTLE UP!",
            "ROUND THREE! PICK UP THE PACE!",
            "ROUND FOUR! STAY FOCUSED!",
            "ROUND FIVE! HALFWAY THERE!",
            "ROUND SIX! KEEP PUSHING!",
            "ROUND SEVEN! DIG DEEPER!",
            "ROUND EIGHT! POWER THROUGH!",
            "ROUND NINE! ALMOST DONE!",
            "ROUND TEN! FINAL PUSH!",
            "ROUND ELEVEN! EVERYTHING YOU GOT!",
            "ROUND TWELVE! FINISH STRONG!"
        ],

        "timing": [
            "THIRTY SECONDS! PICK IT UP!",
            "TWENTY SECONDS! FASTER!",
            "FIFTEEN SECONDS! MAXIMUM EFFORT!",
            "TEN SECONDS! EVERYTHING YOU GOT!",
            "FIVE SECONDS! PUSH IT!",
            "TIME! OUTSTANDING!",
            "ROUND COMPLETE! EXCELLENT WORK!",
            "ONE MINUTE LEFT! STAY STRONG!",
            "TWO MINUTES LEFT! KEEP GOING!",
            "FINAL TEN SECONDS! GIVE IT ALL!",
            "TIME'S UP! WELL DONE!",
            "REST IS OVER! BACK TO WORK!"
        ],

        "motivation": [
            "OUTSTANDING EFFORT!",
            "KEEP PUSHING!",
            "EXCELLENT FORM!",
            "PUSH THROUGH!",
            "STAY FOCUSED!",
            "NEVER QUIT!",
            "YOU'RE STRONG!",
            "FINISH LIKE A CHAMPION!",
            "ONE MORE REP!",
            "FEEL THE POWER!",
            "NO LIMITS!",
            "CHAMPIONS WORK HARD!",
            "THIS IS YOUR MOMENT!",
            "BREAK YOUR LIMITS!",
            "STRONG SPIRIT!",
            "SHOW YOUR STRENGTH!",
            "PAIN IS TEMPORARY!",
            "YOU'RE UNSTOPPABLE!"
        ],

        "instructions": [
            "GUARD UP! PROTECT YOURSELF!",
            "DUCK AND WEAVE!",
            "LIGHT ON YOUR FEET!",
            "BREATHE WITH YOUR PUNCHES!",
            "ROTATE THOSE HIPS!",
            "SNAP BACK FAST!",
            "MOVE THAT HEAD!",
            "STAY BALANCED!",
            "FOCUS ON FORM!",
            "CONTROL YOUR BREATHING!",
            "PIVOT FOR POWER!",
            "HANDS HIGH!",
            "STEP INTO IT!",
            "STAY LOOSE!"
        ],

        "rest": [
            "REST TIME! YOU EARNED IT!",
            "BREATHE DEEP! RECOVER!",
            "HYDRATE NOW!",
            "SHAKE IT OUT!",
            "CATCH YOUR BREATH!",
            "RECOVERY TIME!",
            "RELAX AND RESET!",
            "DEEP BREATHS!",
            "NEXT ROUND COMING!",
            "STAY LOOSE!",
            "TOWEL OFF!",
            "GET READY!"
        ],

        "combinations": [
            # Basic combinations
            "1",
            "2",
            "1 2",
            "1 2 3",
            "1 2 3 2",
            "1 2 slip",
            "1 2 slip 2",
            "2 3",
            "2 3 2",
            "3 2",
            "3 2 3",
            "1 2 3 4",
            "1 2 3 2 3",

            # Intermediate combinations
            "1 2 slip 2 3",
            "1 2 3 2 roll 3",
            "2 3 2 duck 2",
            "1 2 3 4 3 2",
            "1 slip 2 3 2",
            "2 roll 3 2 3",
            "1 2 duck 3 2",
            "3 2 3 slip 2",

            # Advanced combinations
            "1 2 slip 2 3 roll 2",
            "1 2 3 2 duck 3 2 3",
            "2 3 2 slip 2 3 4",
            "1 2 3 4 3 2 roll 3",
            "1 slip 2 3 2 duck 2 3",
            "2 roll 3 2 3 slip 2 3",
            "1 2 duck 3 2 3 4 3",
            "3 2 3 slip 2 roll 3 2",

            # Professional combinations
            "1 2 slip 2 3 roll 2 3 4",
            "1 2 3 2 duck 3 2 3 slip 2",
            "2 3 2 slip 2 3 4 roll 3 2",
            "1 slip 2 3 2 duck 2 3 4 3",
            "2 roll 3 2 3 slip 2 3 duck 2",
            "1 2 duck 3 2 3 4 3 roll 2 3",
            "3 2 3 slip 2 roll 3 2 3 4 3",
            "1 2 3 4 duck 3 2 slip 2 3 4"
        ]
    }


async def main():
    """Main execution function."""
    parser = argparse.ArgumentParser(description="Generate workout audio files using OpenAI TTS")
    parser.add_argument("--api-key", required=True, help="OpenAI API key")
    parser.add_argument("--output-dir", default="assets/audio/workout", help="Output directory")
    parser.add_argument("--voice", default="nova", choices=["alloy", "echo", "fable", "onyx", "nova", "shimmer"], help="Voice to use")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be generated without actually generating")

    args = parser.parse_args()

    # Get all texts to generate
    texts_by_category = get_workout_texts()

    print("🎯 StrengthWave Audio Generator")
    print("=" * 50)

    # Show summary
    total_files = sum(len(texts) for texts in texts_by_category.values())
    print(f"📊 Summary:")
    for category, texts in texts_by_category.items():
        print(f"   {category}: {len(texts)} files")
    print(f"   Total: {total_files} files")
    print()

    if args.dry_run:
        print("🔍 Dry run mode - showing what would be generated:")
        for category, texts in texts_by_category.items():
            print(f"\n{category.upper()}:")
            for text in texts[:3]:  # Show first 3 examples
                print(f"  - {text}")
            if len(texts) > 3:
                print(f"  ... and {len(texts) - 3} more")
        return

    # Estimate cost
    async with OpenAITTSGenerator(args.api_key, args.output_dir) as generator:
        generator.voice = args.voice
        estimated_cost = generator.estimate_cost(texts_by_category)

        print(f"💰 Estimated cost: ${estimated_cost:.4f}")
        print()

        # Confirm generation
        response = input("Continue with generation? (y/N): ")
        if response.lower() != 'y':
            print("❌ Generation cancelled")
            return

        # Setup directories
        generator.setup_directories()
        print()

        # Generate all files
        start_time = time.time()
        results = await generator.generate_batch(texts_by_category)
        end_time = time.time()

        # Save metadata
        metadata = generator.save_metadata()

        # Show results
        print("\n" + "=" * 50)
        print("🎉 Generation Complete!")
        print(f"⏱️  Time taken: {end_time - start_time:.1f} seconds")
        print(f"💰 Actual cost: ${metadata['estimated_cost']:.4f}")
        print(f"📁 Files generated: {metadata['total_files']}")
        print(f"📍 Output directory: {generator.output_dir}")

        # Generate Dart integration code
        generate_dart_integration(generator.output_dir, results)


def generate_dart_integration(output_dir: Path, results: Dict[str, List[Dict]]):
    """Generate Dart integration code for the audio files."""

    dart_code = '''// Generated audio file mappings for StrengthWave
// This file is auto-generated by generate_workout_audio.py

class WorkoutAudioFiles {
  static const String _basePath = 'assets/audio/workout';

'''

    # Generate constants for each category
    for category, files in results.items():
        dart_code += f"  // {category.upper()} audio files\n"
        dart_code += f"  static const Map<String, String> {category} = {{\n"

        for file_info in files:
            if not file_info.get('skipped', False):
                text = file_info['text']
                filename = file_info['filename']
                # Create a safe key from the text
                key = re.sub(r'[^\w]', '_', text.lower()).strip('_')
                dart_code += f"    '{key}': '$_basePath/{category}/{filename}',\n"

        dart_code += "  };\n\n"

    # Add helper methods
    dart_code += '''  /// Get audio file path for a specific text and category
  static String? getAudioPath(String text, String category) {
    final key = text.toLowerCase().replaceAll(RegExp(r'[^\\w]'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');

    switch (category) {
'''

    for category in results.keys():
        dart_code += f"      case '{category}':\n"
        dart_code += f"        return {category}[key];\n"

    dart_code += '''      default:
        return null;
    }
  }

  /// Get all audio files for a category
  static Map<String, String> getCategory(String category) {
    switch (category) {
'''

    for category in results.keys():
        dart_code += f"      case '{category}':\n"
        dart_code += f"        return {category};\n"

    dart_code += '''      default:
        return {};
    }
  }
}
'''

    # Save Dart file
    dart_file = output_dir / "workout_audio_files.dart"
    with open(dart_file, 'w') as f:
        f.write(dart_code)

    print(f"🎯 Generated Dart integration: {dart_file}")


if __name__ == "__main__":
    asyncio.run(main())
