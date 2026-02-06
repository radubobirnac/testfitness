FROM docker/whalesay:latest
LABEL Name=StrengthWave Version=1.0.0
RUN apt-get -y update && apt-get install -y fortunes
CMD ["sh", "-c", "/usr/games/fortune -a | cowsay"]
