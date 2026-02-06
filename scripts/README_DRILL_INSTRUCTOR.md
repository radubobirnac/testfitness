# Drill Instructor Audio Generation

This script generates high-quality drill instructor audio files for the StrengthWave boxing app using OpenAI's GPT-4o mini TTS.

## What it generates

### Countdown Files
- `3.mp3` - "THREE!"
- `2.mp3` - "TWO!"  
- `1.mp3` - "ONE!"

### Boxing Combination Files
All unique combinations from all difficulty levels (beginner, intermediate, advanced, professional), including:
- Basic combinations: `1_2.mp3`, `1_2_3.mp3`, etc.
- Defense moves: `1_2_slip.mp3`, `1_2_duck.mp3`, etc.
- Complex combinations: `1_2_slip_2_3_4_roll.mp3`, etc.

## Setup

1. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Set your OpenAI API key:**
   ```bash
   export OPENAI_API_KEY="your-openai-api-key-here"
   ```
   
   Or on Windows:
   ```cmd
   set OPENAI_API_KEY=your-openai-api-key-here
   ```

## Usage

Run the script to generate all drill instructor audio files:

```bash
python generate_drill_instructor_audio.py
```

## Output

Audio files will be generated in:
- `../assets/audio/drill_instructor/countdown/` - Countdown files
- `../assets/audio/drill_instructor/combinations/` - Boxing combination files

## Voice Configuration

The script uses:
- **Model**: `tts-1` (OpenAI TTS)
- **Voice**: `onyx` (Male, authoritative)
- **Speed**: `1.1` (Slightly faster for drill instructor energy)
- **Format**: MP3

## Cost Estimation

- Countdown files: ~3 files × $0.015/1K chars ≈ $0.01
- Combination files: ~100+ files × $0.015/1K chars ≈ $0.50-1.00
- **Total estimated cost**: ~$1.00-1.50

## Integration

Once generated, the audio files are automatically used by:
- `DrillInstructorAudioService` - Manages audio playback
- `BoxingAudioController` - Integrates with boxing sessions
- Falls back to TTS if audio files are missing

## Troubleshooting

1. **API Key Issues**: Make sure your OpenAI API key is set correctly
2. **Missing Files**: Check the output directories exist
3. **Audio Playback**: Ensure Flutter app has the audioplayers dependency
4. **File Paths**: Verify asset paths in pubspec.yaml are correct

## Regenerating Audio

To regenerate specific files:
1. Delete the existing audio files you want to replace
2. Run the script again - it will only generate missing files
3. Or modify the script to force regeneration of all files
