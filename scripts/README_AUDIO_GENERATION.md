# 🎖️ StrengthWave Drill Instructor Audio Generation

This directory contains scripts to generate high-quality drill instructor audio files for the StrengthWave boxing app using OpenAI's TTS API.

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended)
```bash
scripts/setup_and_generate_audio.bat YOUR_OPENAI_API_KEY
```

### Option 2: Manual Setup
```bash
# Install dependencies
pip install -r scripts/requirements.txt

# Generate audio files
python scripts/generate_countdown_audio.py YOUR_OPENAI_API_KEY
```

## 📋 What Gets Generated

### 🎯 Countdown Files (timing/)
- `countdown_3_drill_instructor.mp3` - "THREE!"
- `countdown_2_drill_instructor.mp3` - "TWO!"
- `countdown_1_drill_instructor.mp3` - "ONE!"

### 🥊 Boxing Combinations (combinations/)
- Individual punches: "ONE!", "TWO!", "THREE!", etc.
- Defense moves: "SLIP!", "DUCK!", "ROLL!", etc.
- Combinations: "ONE TWO SLIP TWO!", etc.

### ⏰ Timing Calls (timing/)
- "THIRTY SECONDS! PICK IT UP!"
- "TEN SECONDS! EVERYTHING YOU GOT!"
- "TIME! OUTSTANDING!"
- And more...

### 💪 Motivation Phrases (motivation/)
- "BEAST MODE! UNLEASH THE FURY!"
- "NO MERCY! NO QUIT!"
- "CRUSH IT, SOLDIER!"
- And more...

## 🔧 Technical Details

- **Voice**: OpenAI "onyx" (drill instructor style)
- **Model**: tts-1-hd (high quality)
- **Format**: MP3
- **Speed**: Optimized per category
  - Countdown: 1.0x (clarity)
  - Combinations: 1.2x (energy)
  - Motivation: 1.3x (maximum intensity)

## 💰 Cost Estimation

Approximate cost for generating all files:
- ~50 audio files
- Average 3-5 words per file
- Cost: ~$0.50-$1.00 total

## 🔑 Getting Your OpenAI API Key

1. Go to https://platform.openai.com/api-keys
2. Create a new API key
3. Copy the key (starts with `sk-`)
4. Use it with the scripts above

## 🎵 Audio File Structure

```
assets/audio/workout/
├── timing/
│   ├── countdown_3_drill_instructor.mp3
│   ├── countdown_2_drill_instructor.mp3
│   ├── countdown_1_drill_instructor.mp3
│   └── [timing phrases...]
├── combinations/
│   ├── 1.mp3
│   ├── 2.mp3
│   ├── 1_2_slip_2.mp3
│   └── [combinations...]
└── motivation/
    ├── beast_mode_unleash_the_fury.mp3
    └── [motivation phrases...]
```

## 🚨 Troubleshooting

### "Module not found" error
```bash
pip install aiohttp aiofiles
```

### "Invalid API key" error
- Check your API key is correct
- Ensure you have credits in your OpenAI account

### "Permission denied" error
- Run from the project root directory
- Ensure the `assets/audio/workout/` directory exists

## 🎖️ Result

After running the script, your boxing app will have:
- ✅ Commanding countdown: "THREE! TWO! ONE!"
- ✅ High-energy combinations with drill instructor voice
- ✅ No more boring TTS fallback
- ✅ Maximum motivation and intensity

🥊 **GET READY TO DOMINATE YOUR WORKOUT!**
