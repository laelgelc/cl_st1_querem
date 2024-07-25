#!/bin/bash

clear

# Updating and upgrading the system
sudo apt update && sudo apt upgrade -y || { echo "Failed to update and upgrade packages"; exit 1; }

# Installing necessary packages
sudo snap install aws-cli --classic
sudo apt install -y python3-pip python3-venv ripgrep html2text zip unzip pipx

# Creating directory for TreeTagger
mkdir -p "$HOME"/treetagger/

# Defining base URL for TreeTagger files
BASE_URL="https://cis.uni-muenchen.de/~schmid/tools/TreeTagger/data"

# Downloading TreeTagger 
cd "$HOME"/treetagger/
curl -O ${BASE_URL}/tree-tagger-linux-3.2.5.tar.gz
curl -O ${BASE_URL}/tagger-scripts.tar.gz
curl -O ${BASE_URL}/install-tagger.sh
curl -O ${BASE_URL}/english.par.gz
curl -O ${BASE_URL}/portuguese2.par.gz

# Installing TreeTagger
chmod +x "$HOME"/treetagger/install-tagger.sh
"$HOME"/treetagger/install-tagger.sh

# Appending TreeTagger paths to .bashrc
echo >> "$HOME"/.bashrc
echo "# The following lines add TreeTagger to the PATH variable" >> "$HOME"/.bashrc
echo "export PATH=\$PATH:/home/ubuntu/treetagger/cmd" >> "$HOME"/.bashrc
echo "export PATH=\$PATH:/home/ubuntu/treetagger/bin" >> "$HOME"/.bashrc

# Setting up Python virtual environment
cd "$HOME"
python3 -m venv my_env
source "$HOME"/my_env/bin/activate
pip install \
beautifulsoup4 \
boto3 \
demoji \
gensim \
gogettr \
google.cloud \
ipython \
jupyterlab \
lxml \
matplotlib \
nltk \
numpy \
openai \
openpyxl \
pandas \
pySmartDL \
pyspark \
python-dotenv \
requests \
scipy \
truthbrush \
webvtt-py
python -m ipykernel install --user --name=my_env

# Deactivating the 'my_env' environment
deactivate

echo "Attach the 'S3-Admin-Access' IAM role to the EC2 instance via AWS Console"
echo "Reboot the EC2 instance via AWS Console"
