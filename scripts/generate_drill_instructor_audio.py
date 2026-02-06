#!/usr/bin/env python3
"""
Generate drill instructor audio files for StrengthWave boxing app
Uses OpenAI GPT-4o mini TTS to create high-energy drill instructor voice
"""

import asyncio
import os
import re
from pathlib import Path
from typing import Dict, List, Set
import aiohttp
import aiofiles
from datetime import datetime

class DrillInstructorAudioGenerator:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://api.openai.com/v1/audio/speech"
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }

    async def generate_audio_file(self, text: str, filename: str, output_dir: Path):
        """Generate a single audio file using OpenAI TTS"""
        try:
            payload = {
                "model": "tts-1-hd",  # Using HD model for consistent quality
                "input": text,
                "voice": "onyx",  # Male voice with authority - good for drill instructor
                "response_format": "mp3",
                "speed": 1.0  # Normal speed for consistency
            }

            async with aiohttp.ClientSession() as session:
                async with session.post(self.base_url, headers=self.headers, json=payload) as response:
                    if response.status == 200:
                        audio_data = await response.read()
                        file_path = output_dir / f"{filename}.mp3"

                        async with aiofiles.open(file_path, 'wb') as f:
                            await f.write(audio_data)

                        print(f"✅ Generated: {filename}.mp3 - '{text}'")
                        return True
                    else:
                        error_text = await response.text()
                        print(f"❌ Failed to generate {filename}: {response.status} - {error_text}")
                        return False

        except Exception as e:
            print(f"❌ Error generating {filename}: {str(e)}")
            return False

    async def generate_countdown_files(self, output_dir: Path):
        """Generate countdown audio files: 3, 2, 1"""
        countdown_dir = output_dir / "countdown"
        countdown_dir.mkdir(parents=True, exist_ok=True)

        countdown_items = [
            ("3", "THREE!"),
            ("2", "TWO!"),
            ("1", "ONE!")
        ]

        print("🎖️ Generating drill instructor countdown files...")

        tasks = []
        for filename, text in countdown_items:
            task = self.generate_audio_file(text, filename, countdown_dir)
            tasks.append(task)

        results = await asyncio.gather(*tasks)
        success_count = sum(results)
        print(f"🎖️ Countdown generation complete: {success_count}/{len(countdown_items)} files generated")

    def get_top_70_combinations(self) -> List[str]:
        """Get exactly 70 most important boxing combinations for drill instructor audio"""
        # Curated list of 70 essential combinations, ordered by importance/frequency
        top_combinations = [
            # Basic punches (10)
            '1-2', '1-2-3', '1-2-3-2', '2-3', '2-3-4',
            '3-4', '1-6', '5-2', '5-6', '1-2-5',

            # Basic defense (10)
            '1-2-slip', '1-2-slip-2', '2-3-slip', '3-slip', '1-slip',
            '1-2-duck', '2-duck', '3-duck', '1-2-roll', '2-roll',

            # Intermediate combinations (15)
            '1-2-3-4', '2-3-4-3', '3-4-3', '1-2-5-6', '3-4-3-2',
            '1-2-slip-2-3', '2-3-roll', '3-4-roll', '1-6-3', '5-2-slip',
            '1-2-3-duck', '2-duck-3', '3-slip-2', '1-6-3-2', '2-3-roll-2',

            # Advanced combinations (15)
            '1-2-slip-2-3-4', '3-2-roll', '2-3-roll-2-4', '1-6-3-2-slip',
            '3-slip-2-1', '2-duck-3-4', '1-2-3-duck-4', '5-2-slip-3',
            '3-4-roll-1', '1-2-3-parry', '2-slip-2-3', '3-2-roll-4',
            '1-2-slip-2-3-4-roll', '5-2-slip-3-4', '1-2-3-parry-2-4-3',

            # Professional combinations (10)
            '1-2-slip-2-3-4-roll-3-2', '3-2-duck-4', '1-6-3-2-duck-4',
            '2-slip-2-3-roll', '1-2-3-parry-2', '3-2-roll-4-3',
            '5-6-slip-2-3', '1-2-3-roll-4', '2-slip-3-4-roll',
            '1-2-duck-3-2-slip',

            # Complex sequences (10)
            '3-2-duck-4-3-slip', '1-2-3-duck-4-2', '2-duck-3-4-roll',
            '3-slip-2-1-4', '1-2-3-parry-2-4', '5-2-slip-3-4-2',
            '3-4-roll-1-2', '1-6-3-2-duck-4-3', '2-slip-3-4-roll-1-2',
            '1-2-duck-3-2-slip-4-3'
        ]

        # Ensure we have exactly 70
        assert len(top_combinations) == 70, f"Expected 70 combinations, got {len(top_combinations)}"
        return top_combinations

    def convert_combination_to_speech(self, combination: str) -> str:
        """Convert combination notation to drill instructor speech"""
        # Replace numbers and movements with drill instructor callouts
        speech = combination.upper()

        # Replace numbers
        speech = speech.replace('1', 'ONE')
        speech = speech.replace('2', 'TWO')
        speech = speech.replace('3', 'THREE')
        speech = speech.replace('4', 'FOUR')
        speech = speech.replace('5', 'FIVE')
        speech = speech.replace('6', 'SIX')

        # Replace movements
        speech = speech.replace('SLIP', 'SLIP')
        speech = speech.replace('DUCK', 'DUCK')
        speech = speech.replace('ROLL', 'ROLL')
        speech = speech.replace('PARRY', 'PARRY')

        # Replace dashes with spaces and add energy
        speech = speech.replace('-', ' ')

        # Add drill instructor energy
        return f"{speech}!"

    def create_safe_filename(self, combination: str) -> str:
        """Create a safe filename from combination notation"""
        return combination.replace('-', '_').lower()

    async def generate_combination_files(self, output_dir: Path):
        """Generate exactly 70 boxing combination audio files"""
        combinations_dir = output_dir / "combinations"
        combinations_dir.mkdir(parents=True, exist_ok=True)

        top_combinations = self.get_top_70_combinations()

        print(f"🥊 Generating {len(top_combinations)} drill instructor combination files...")
        print("🎖️ Using HD quality and consistent tempo for drill instructor voice")

        # Generate files in smaller batches for better consistency
        batch_size = 5  # Smaller batches for more consistent quality

        for i in range(0, len(top_combinations), batch_size):
            batch = top_combinations[i:i + batch_size]
            tasks = []

            for combination in batch:
                speech_text = self.convert_combination_to_speech(combination)
                filename = self.create_safe_filename(combination)
                task = self.generate_audio_file(speech_text, filename, combinations_dir)
                tasks.append(task)

            results = await asyncio.gather(*tasks)
            success_count = sum(results)
            print(f"🥊 Batch {i//batch_size + 1} complete: {success_count}/{len(batch)} files generated")

            # Longer delay between batches for API stability and consistency
            await asyncio.sleep(2)

    async def generate_all_files(self, output_dir: Path):
        """Generate drill instructor audio files"""
        print("🎖️ Starting drill instructor audio generation...")
        print(f"📁 Output directory: {output_dir}")

        # Create output directory
        output_dir.mkdir(parents=True, exist_ok=True)

        # Skip countdown files (already exist and working)
        print("⏭️ Skipping countdown files (already exist)")

        # Generate only combination files
        await self.generate_combination_files(output_dir)

        print("🎖️ Drill instructor audio generation complete!")

async def main():
    """Main function to generate all drill instructor audio files"""
    # Get API key from environment variable
    api_key = os.getenv('OPENAI_API_KEY')
    if not api_key:
        print("❌ Error: OPENAI_API_KEY environment variable not set")
        print("Please set your OpenAI API key: export OPENAI_API_KEY='your-key-here'")
        return

    # Set output directory
    script_dir = Path(__file__).parent
    output_dir = script_dir.parent / "assets" / "audio" / "drill_instructor"

    # Generate all files
    generator = DrillInstructorAudioGenerator(api_key)
    await generator.generate_all_files(output_dir)

if __name__ == "__main__":
    asyncio.run(main())
