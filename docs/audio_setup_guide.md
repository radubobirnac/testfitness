# StrengthWave High-Quality Audio Setup Guide

This guide explains how to replace the default Flutter TTS with high-quality pre-recorded OpenAI TTS audio files for your StrengthWave boxing/workout app.

## Overview

The solution provides:
- **High-quality audio**: OpenAI TTS-1-HD model with professional voice quality
- **Offline playback**: Works completely offline after initial setup
- **Fast performance**: Pre-recorded files eliminate TTS generation delays
- **Consistent pronunciation**: No variation in voice quality or pronunciation
- **Fallback support**: Automatically falls back to system TTS if audio files are missing
- **Cost-effective**: Under $0.01 to generate all 60+ audio files

## Prerequisites

### Python Requirements
```bash
pip install aiohttp aiofiles
```

### OpenAI API Key
You'll need an OpenAI API key with access to the TTS API. Get one from [OpenAI Platform](https://platform.openai.com/api-keys).

### Flutter Dependencies
The required dependencies are already included in `pubspec.yaml`:
- `audioplayers: ^5.2.1` - For audio playback
- `flutter_tts: ^4.2.2` - For fallback TTS

## Step 1: Generate Audio Files

### 1.1 Run the Audio Generation Script

Navigate to your project root and run:

```bash
# Dry run to see what will be generated
python scripts/generate_workout_audio.py --api-key "YOUR_OPENAI_API_KEY" --dry-run

# Generate all audio files
python scripts/generate_workout_audio.py --api-key "YOUR_OPENAI_API_KEY"
```

### 1.2 Script Options

```bash
python scripts/generate_workout_audio.py \
  --api-key "YOUR_OPENAI_API_KEY" \
  --output-dir "assets/audio/workout" \
  --voice "nova" \
  --dry-run
```

**Available voices:**
- `nova` (default) - Energetic female voice, great for motivation
- `alloy` - Balanced, neutral voice
- `echo` - Male voice with good clarity
- `fable` - Expressive female voice
- `onyx` - Deep male voice
- `shimmer` - Soft female voice

### 1.3 Generated Files Structure

The script creates this directory structure:
```
assets/audio/workout/
├── rounds/           # Round announcements (12 files)
├── timing/           # Time warnings and callouts (12 files)
├── motivation/       # Motivational phrases (18 files)
├── instructions/     # Boxing instructions (14 files)
├── rest/            # Rest period announcements (12 files)
├── combinations/    # Boxing combinations (48 files)
├── metadata.json    # Generation metadata
└── workout_audio_files.dart  # Generated Dart mappings
```

### 1.4 Cost Estimation

Expected cost: **$0.008 - $0.012** (less than 1 cent)
- Total characters: ~800-1200
- TTS-1-HD pricing: $0.015 per 1K characters

## Step 2: Integration

### 2.1 Copy Generated Files

The audio files are automatically generated in the correct location (`assets/audio/workout/`). The Flutter app will detect them automatically.

### 2.2 Update Asset Mappings

The app already uses `lib/services/workout_audio_files.dart` for audio lookups. No additional wiring is required after copying the generated file.

### 2.3 Test the Integration

The app will automatically:
1. Try to load pre-recorded audio files
2. Fall back to enhanced TTS if files are missing
3. Log the audio source being used

Check the logs to confirm audio files are being detected:
```
I/flutter: Pre-recorded audio files detected
I/flutter: WorkoutAudioPlayer initialized successfully
I/flutter: Playing pre-recorded audio: round_1_fight_12345678.mp3
```

## Step 3: Verification

### 3.1 Test Boxing Session

1. Open the StrengthWave app
2. Navigate to Boxing Cardio
3. Start a boxing session
4. Listen for high-quality audio announcements

### 3.2 Check Audio Quality

You should notice:
- **Clearer voice quality** compared to system TTS
- **Consistent pronunciation** of boxing terms
- **Faster audio playback** (no generation delay)
- **Professional motivation** in the voice tone

### 3.3 Verify Fallback

To test the fallback system:
1. Temporarily rename the `assets/audio/workout` directory
2. Restart the app
3. Verify it falls back to enhanced TTS
4. Restore the directory name

## Troubleshooting

### Audio Files Not Found

**Symptoms:**
- App logs show "Pre-recorded audio files not found"
- Falls back to system TTS

**Solutions:**
1. Verify files exist in `assets/audio/workout/`
2. Run `flutter clean && flutter pub get`
3. Check `pubspec.yaml` includes audio asset directories
4. Rebuild the app

### Poor Audio Quality

**Symptoms:**
- Audio sounds robotic or unclear
- Voice doesn't match expected quality

**Solutions:**
1. Regenerate with different voice (try `nova` or `fable`)
2. Check if using TTS-1-HD model (not TTS-1)
3. Verify audio files aren't corrupted

### Generation Errors

**Common errors and solutions:**

**API Key Issues:**
```bash
Error: 401 Unauthorized
```
- Verify your OpenAI API key is correct
- Check API key has TTS access enabled

**Rate Limiting:**
```bash
Error: 429 Too Many Requests
```
- The script includes rate limiting (200ms delays)
- Wait a few minutes and retry

**Network Issues:**
```bash
Error: Connection timeout
```
- Check internet connection
- Retry the generation

### Performance Issues

**Slow Audio Loading:**
- Pre-load audio categories using `BoxingAudioController.preloadBoxingAudio()`
- Reduce concurrent requests in generation script

**Memory Usage:**
- Audio files are small (1-3KB each)
- Total memory impact: ~200KB for all files

## Advanced Configuration

### Custom Voice Settings

Modify the generation script to use custom settings:

```python
# In generate_workout_audio.py
generator.voice = "nova"        # Change voice
generator.model = "tts-1-hd"    # Use HD model
generator.format = "mp3"        # Audio format
```

### Adding Custom Phrases

Add your own phrases to the generation script:

```python
# In get_workout_texts() function
"motivation": [
    "You've got this!",
    "Your custom phrase here!",
    # ... existing phrases
]
```

### Volume and Playback Settings

Adjust audio settings in the app:

```dart
// Set volume (0.0 to 1.0)
await BoxingAudioController().setVolume(0.8);

// Set motivation frequency (every N combinations)
BoxingAudioController().setMotivationFrequency(3);
```

## Benefits Summary

✅ **Professional Quality**: OpenAI TTS-1-HD provides studio-quality voice  
✅ **Offline Operation**: No internet required after setup  
✅ **Consistent Performance**: No TTS generation delays during workouts  
✅ **Cost Effective**: One-time cost under $0.01  
✅ **Automatic Fallback**: Graceful degradation to system TTS  
✅ **Easy Maintenance**: Simple script to regenerate files  

## Support

If you encounter issues:

1. Check the app logs for error messages
2. Verify all prerequisites are installed
3. Test with a dry run first
4. Ensure your OpenAI API key has TTS access

The audio system is designed to be robust with automatic fallbacks, so your app will continue working even if there are issues with the pre-recorded files.
