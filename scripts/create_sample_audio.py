#!/usr/bin/env python3
"""
Create sample audio files for testing the drill instructor system
This creates basic MP3 files using system TTS or placeholder files
"""

import os
import subprocess
import sys
from pathlib import Path

def create_sample_audio_files():
    """Create sample audio files for testing"""
    
    # Get the project root directory
    script_dir = Path(__file__).parent
    assets_dir = script_dir.parent / "assets" / "audio" / "drill_instructor"
    
    # Create directories
    countdown_dir = assets_dir / "countdown"
    combinations_dir = assets_dir / "combinations"
    
    countdown_dir.mkdir(parents=True, exist_ok=True)
    combinations_dir.mkdir(parents=True, exist_ok=True)
    
    print("🎖️ Creating sample drill instructor audio files...")
    
    # Create countdown files
    countdown_files = {
        "3": "THREE!",
        "2": "TWO!",
        "1": "ONE!"
    }
    
    for filename, text in countdown_files.items():
        output_path = countdown_dir / f"{filename}.mp3"
        if create_audio_file(text, output_path):
            print(f"✅ Created countdown: {filename}.mp3")
        else:
            print(f"❌ Failed to create: {filename}.mp3")
    
    # Create sample combination files
    sample_combinations = {
        "1_2": "ONE TWO!",
        "1_2_3": "ONE TWO THREE!",
        "1_2_slip": "ONE TWO SLIP!",
        "1_2_slip_2": "ONE TWO SLIP TWO!",
        "2_3": "TWO THREE!",
        "2_3_4": "TWO THREE FOUR!",
        "3_4": "THREE FOUR!",
        "1_2_3_2": "ONE TWO THREE TWO!",
        "2_3_roll": "TWO THREE ROLL!",
        "1_6": "ONE SIX!",
        "5_2": "FIVE TWO!",
        "3_slip": "THREE SLIP!",
        "2_duck": "TWO DUCK!",
        "1_2_3_duck": "ONE TWO THREE DUCK!",
        "3_4_roll": "THREE FOUR ROLL!",
        "1_2_3_parry": "ONE TWO THREE PARRY!"
    }
    
    for filename, text in sample_combinations.items():
        output_path = combinations_dir / f"{filename}.mp3"
        if create_audio_file(text, output_path):
            print(f"✅ Created combination: {filename}.mp3")
        else:
            print(f"❌ Failed to create: {filename}.mp3")
    
    print(f"🎖️ Sample audio creation complete!")
    print(f"📁 Countdown files: {countdown_dir}")
    print(f"📁 Combination files: {combinations_dir}")

def create_audio_file(text, output_path):
    """Create an audio file using available TTS tools"""
    
    try:
        # Try different TTS methods based on platform
        if sys.platform == "win32":
            return create_audio_windows(text, output_path)
        elif sys.platform == "darwin":
            return create_audio_macos(text, output_path)
        else:
            return create_audio_linux(text, output_path)
    except Exception as e:
        print(f"Error creating audio for '{text}': {e}")
        # Create a placeholder file
        return create_placeholder_file(output_path)

def create_audio_windows(text, output_path):
    """Create audio on Windows using PowerShell and SAPI"""
    try:
        # Use PowerShell with SAPI (Speech API)
        ps_script = f'''
Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.Rate = 2
$synth.Volume = 100
$synth.SetOutputToWaveFile("{output_path.with_suffix('.wav')}")
$synth.Speak("{text}")
$synth.Dispose()
'''
        
        # Run PowerShell script
        result = subprocess.run(
            ["powershell", "-Command", ps_script],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            # Convert WAV to MP3 if ffmpeg is available
            wav_path = output_path.with_suffix('.wav')
            if wav_path.exists():
                try:
                    subprocess.run([
                        "ffmpeg", "-i", str(wav_path), "-codec:a", "mp3", 
                        "-b:a", "128k", str(output_path), "-y"
                    ], capture_output=True, timeout=30)
                    wav_path.unlink()  # Delete WAV file
                    return output_path.exists()
                except:
                    # If ffmpeg fails, rename WAV to MP3
                    wav_path.rename(output_path.with_suffix('.mp3'))
                    return True
        
        return False
        
    except Exception as e:
        print(f"Windows TTS failed: {e}")
        return False

def create_audio_macos(text, output_path):
    """Create audio on macOS using say command"""
    try:
        # Use macOS 'say' command
        result = subprocess.run([
            "say", "-v", "Alex", "-r", "200", "-o", str(output_path.with_suffix('.aiff')), text
        ], capture_output=True, timeout=30)
        
        if result.returncode == 0:
            # Convert AIFF to MP3 if ffmpeg is available
            aiff_path = output_path.with_suffix('.aiff')
            try:
                subprocess.run([
                    "ffmpeg", "-i", str(aiff_path), "-codec:a", "mp3", 
                    "-b:a", "128k", str(output_path), "-y"
                ], capture_output=True, timeout=30)
                aiff_path.unlink()  # Delete AIFF file
                return output_path.exists()
            except:
                # If ffmpeg fails, keep AIFF and rename
                aiff_path.rename(output_path.with_suffix('.mp3'))
                return True
        
        return False
        
    except Exception as e:
        print(f"macOS TTS failed: {e}")
        return False

def create_audio_linux(text, output_path):
    """Create audio on Linux using espeak or festival"""
    try:
        # Try espeak first
        result = subprocess.run([
            "espeak", "-s", "180", "-v", "en+m3", "-w", str(output_path.with_suffix('.wav')), text
        ], capture_output=True, timeout=30)
        
        if result.returncode == 0:
            # Convert WAV to MP3 if ffmpeg is available
            wav_path = output_path.with_suffix('.wav')
            try:
                subprocess.run([
                    "ffmpeg", "-i", str(wav_path), "-codec:a", "mp3", 
                    "-b:a", "128k", str(output_path), "-y"
                ], capture_output=True, timeout=30)
                wav_path.unlink()  # Delete WAV file
                return output_path.exists()
            except:
                # If ffmpeg fails, rename WAV to MP3
                wav_path.rename(output_path.with_suffix('.mp3'))
                return True
        
        return False
        
    except Exception as e:
        print(f"Linux TTS failed: {e}")
        return False

def create_placeholder_file(output_path):
    """Create a placeholder MP3 file"""
    try:
        # Create a minimal MP3 file (silent)
        # This is a basic MP3 header for a short silent file
        mp3_header = bytes([
            0xFF, 0xFB, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ])
        
        with open(output_path, 'wb') as f:
            f.write(mp3_header * 100)  # Write multiple frames for ~1 second
        
        print(f"Created placeholder file: {output_path}")
        return True
        
    except Exception as e:
        print(f"Failed to create placeholder: {e}")
        return False

if __name__ == "__main__":
    create_sample_audio_files()
