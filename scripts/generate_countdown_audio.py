#!/usr/bin/env python3
"""
Generate ALL essential boxing audio files for StrengthWave boxing app.
This script creates high-quality TTS audio files using OpenAI's TTS API with drill instructor voice.
"""

import asyncio
import aiohttp
import aiofiles
import os
import sys
from pathlib import Path

def load_env_file():
    """Load environment variables from .env file"""
    env_vars = {}
    env_path = Path(".env")

    if env_path.exists():
        with open(env_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()

    return env_vars

class BoxingAudioGenerator:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://api.openai.com/v1/audio/speech"
        self.voice = "onyx"  # Drill instructor voice - commanding and energetic
        self.model = "tts-1-hd"  # High quality
        self.format = "mp3"
        self.speed = 1.1  # Slightly faster for drill instructor energy

    async def generate_audio_file(self, session, text: str, filepath: Path, category: str):
        """Generate a single audio file"""
        print(f"  🔊 Generating: {text} -> {filepath.name}")

        # Adjust speed based on category
        speed = self.speed
        if category == "combinations":
            speed = 1.2  # Faster for combinations
        elif category == "countdown":
            speed = 1.0  # Normal speed for countdown clarity
        elif category == "motivation":
            speed = 1.3  # Fastest for motivation

        payload = {
            "model": self.model,
            "input": text,
            "voice": self.voice,
            "response_format": self.format,
            "speed": speed
        }

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        try:
            async with session.post(self.base_url, json=payload, headers=headers) as response:
                if response.status == 200:
                    audio_data = await response.read()

                    # Save audio file
                    async with aiofiles.open(filepath, 'wb') as f:
                        await f.write(audio_data)

                    print(f"  ✅ Generated: {filepath.name} ({len(audio_data)} bytes)")
                    return True
                else:
                    error_text = await response.text()
                    print(f"  ❌ Failed to generate {filepath.name}: {response.status} - {error_text}")
                    return False

        except Exception as e:
            print(f"  ❌ Error generating {filepath.name}: {e}")
            return False

    async def generate_countdown_files(self, output_dir: Path):
        """Generate countdown audio files (3, 2, 1)"""
        timing_dir = output_dir / "timing"
        timing_dir.mkdir(parents=True, exist_ok=True)

        countdown_texts = {
            "countdown_3_drill_instructor": "THREE!",
            "countdown_2_drill_instructor": "TWO!",
            "countdown_1_drill_instructor": "ONE!"
        }

        print("🎖️ Generating DRILL INSTRUCTOR countdown files...")

        async with aiohttp.ClientSession() as session:
            for filename, text in countdown_texts.items():
                filepath = timing_dir / f"{filename}.mp3"
                await self.generate_audio_file(session, text, filepath, "countdown")
                await asyncio.sleep(0.3)  # Rate limiting

    async def generate_combination_files(self, output_dir: Path):
        """Generate boxing combination audio files"""
        combinations_dir = output_dir / "combinations"
        combinations_dir.mkdir(parents=True, exist_ok=True)

        # Essential boxing combinations
        combinations = {
            "1": "ONE!",
            "2": "TWO!",
            "3": "THREE!",
            "4": "FOUR!",
            "5": "FIVE!",
            "6": "SIX!",
            "1_2": "ONE TWO!",
            "1_2_3": "ONE TWO THREE!",
            "1_2_3_2": "ONE TWO THREE TWO!",
            "slip": "SLIP!",
            "duck": "DUCK!",
            "roll": "ROLL!",
            "block": "BLOCK!",
            "parry": "PARRY!",
            "1_2_slip": "ONE TWO SLIP!",
            "1_2_slip_2": "ONE TWO SLIP TWO!",
            "2_3_4": "TWO THREE FOUR!",
            "3_2_3_2": "THREE TWO THREE TWO!",
            "1_2_3_2_slip": "ONE TWO THREE TWO SLIP!",
            "1_2_3_2_slip_2": "ONE TWO THREE TWO SLIP TWO!",
        }

        print("🥊 Generating BOXING COMBINATION files...")

        async with aiohttp.ClientSession() as session:
            for filename, text in combinations.items():
                filepath = combinations_dir / f"{filename}.mp3"
                await self.generate_audio_file(session, text, filepath, "combinations")
                await asyncio.sleep(0.3)  # Rate limiting

    async def generate_timing_files(self, output_dir: Path):
        """Generate timing and motivation audio files"""
        timing_dir = output_dir / "timing"
        timing_dir.mkdir(parents=True, exist_ok=True)

        timing_phrases = {
            "thirty_seconds_pick_it_up": "THIRTY SECONDS! PICK IT UP!",
            "twenty_seconds_faster": "TWENTY SECONDS! FASTER!",
            "fifteen_seconds_maximum_effort": "FIFTEEN SECONDS! MAXIMUM EFFORT!",
            "ten_seconds_everything_you_got": "TEN SECONDS! EVERYTHING YOU GOT!",
            "five_seconds_push_it": "FIVE SECONDS! PUSH IT!",
            "time_outstanding": "TIME! OUTSTANDING!",
            "round_complete_excellent_work": "ROUND COMPLETE! EXCELLENT WORK!",
            "one_minute_left_stay_strong": "ONE MINUTE LEFT! STAY STRONG!",
            "two_minutes_left_keep_going": "TWO MINUTES LEFT! KEEP GOING!",
            "final_ten_seconds_give_it_all": "FINAL TEN SECONDS! GIVE IT ALL!",
            "times_up_well_done": "TIME'S UP! WELL DONE!",
            "rest_is_over_back_to_work": "REST IS OVER! BACK TO WORK!",
        }

        print("⏰ Generating TIMING files...")

        async with aiohttp.ClientSession() as session:
            for filename, text in timing_phrases.items():
                filepath = timing_dir / f"{filename}.mp3"
                await self.generate_audio_file(session, text, filepath, "timing")
                await asyncio.sleep(0.3)  # Rate limiting

    async def generate_motivation_files(self, output_dir: Path):
        """Generate motivation audio files"""
        motivation_dir = output_dir / "motivation"
        motivation_dir.mkdir(parents=True, exist_ok=True)

        motivation_phrases = {
            "beast_mode_unleash_the_fury": "BEAST MODE! UNLEASH THE FURY!",
            "push_through_the_pain": "PUSH THROUGH THE PAIN!",
            "you_got_this_warrior": "YOU GOT THIS, WARRIOR!",
            "no_mercy_no_quit": "NO MERCY! NO QUIT!",
            "dominate_this_round": "DOMINATE THIS ROUND!",
            "show_me_what_you_got": "SHOW ME WHAT YOU GOT!",
            "crush_it_soldier": "CRUSH IT, SOLDIER!",
            "maximum_intensity": "MAXIMUM INTENSITY!",
            "break_your_limits": "BREAK YOUR LIMITS!",
            "unstoppable_force": "UNSTOPPABLE FORCE!",
        }

        print("💪 Generating MOTIVATION files...")

        async with aiohttp.ClientSession() as session:
            for filename, text in motivation_phrases.items():
                filepath = motivation_dir / f"{filename}.mp3"
                await self.generate_audio_file(session, text, filepath, "motivation")
                await asyncio.sleep(0.3)  # Rate limiting

async def main():
    print("🎖️ DRILL INSTRUCTOR AUDIO GENERATOR")

    # Try to get API key from command line argument first, then .env file
    api_key = None

    if len(sys.argv) >= 2:
        api_key = sys.argv[1]
        print("📝 Using API key from command line argument")
    else:
        # Try to load from .env file
        env_vars = load_env_file()
        api_key = env_vars.get('OPENAI_API_KEY')

        if api_key:
            print("📝 Using API key from .env file")
        else:
            print("❌ No API key found!")
            print("\nOptions:")
            print("1. Add OPENAI_API_KEY to .env file")
            print("2. Run: python generate_countdown_audio.py <API_KEY>")
            print("\nExample: python generate_countdown_audio.py sk-...")
            print("\nThis will generate ALL essential boxing audio files:")
            print("  - Countdown: THREE! TWO! ONE!")
            print("  - Combinations: 1-2-slip-2, etc.")
            print("  - Timing: Time warnings and round completion")
            print("  - Motivation: Beast mode phrases")
            sys.exit(1)

    output_dir = Path("assets/audio/workout")

    # Ensure we're in the right directory
    if not os.path.exists("assets"):
        print("❌ Please run this script from the project root directory")
        sys.exit(1)

    generator = BoxingAudioGenerator(api_key)

    print("🎖️ GENERATING ALL DRILL INSTRUCTOR AUDIO FILES...")
    print("   This will create high-energy, commanding audio for boxing!")
    print()

    # Generate all audio categories
    await generator.generate_countdown_files(output_dir)
    await generator.generate_combination_files(output_dir)
    await generator.generate_timing_files(output_dir)
    await generator.generate_motivation_files(output_dir)

    print()
    print("🎉 ALL DRILL INSTRUCTOR AUDIO GENERATION COMPLETE!")
    print(f"📁 Files saved to: {output_dir}")
    print()
    print("🚀 Your boxing app is now ready with:")
    print("   ✅ Commanding countdown: THREE! TWO! ONE!")
    print("   ✅ High-energy combinations: ONE TWO SLIP TWO!")
    print("   ✅ Motivational timing calls")
    print("   ✅ Beast mode motivation phrases")
    print()
    print("🥊 GET READY TO DOMINATE YOUR WORKOUT!")

if __name__ == "__main__":
    asyncio.run(main())
