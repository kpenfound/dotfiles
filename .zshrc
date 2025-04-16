# If you come from bash you might have to change your $PATH.

# Path to your oh-my-zsh installation.
export ZSH="/Users/kylepenfound/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="kpenfound"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git command-not-found )

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

alias syncfork="git fetch upstream main && git merge upstream/main && git push origin main"

export PATH=/usr/local/go/bin:$PATH

eval "$(/opt/homebrew/bin/brew shellenv)"

# FUNCTIONS

# Function to build and run a Dagger development engine container from a GitHub PR
# Usage: run_dagger_pr <PR_NUMBER>
# Example: run_dagger_pr 5012

dagger_pr() {
  # --- Input Validation ---
  if [[ -z "$1" ]]; then
    echo "Usage: run_dagger_pr <PR_NUMBER>" >&2
    echo "Error: Pull Request number is required." >&2
    return 1
  fi

  local PR_NUMBER="$1"
  # Optional: Validate if it's a number
  if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: PR_NUMBER '$PR_NUMBER' must be a positive integer." >&2
    return 1
  fi

  # --- Configuration ---
  local CONTAINER_NAME="dagger-dev"
  local BIN_DIR="/Users/kylepenfound/bin"
  local BIN_PATH="$BIN_DIR/dagger"
  local EXPORT_DIR="/Users/kylepenfound/builds"
  local EXPORT_PATH="$EXPORT_DIR/engine.tar"
  local DAGGER_MODULE="github.com/dagger/dagger@pull/$PR_NUMBER/head"
  local DOCKER_VOLUME="/var/lib/dagger" # Standard volume used by Dagger engine

  echo "--- Starting Dagger PR build for PR #$PR_NUMBER ---"

  # Ensure the export directory exists
  mkdir -p "$EXPORT_DIR" || { echo "Error: Failed to create directory $EXPORT_DIR" >&2; return 1; }
  mkdir -p "$BIN_DIR" || { echo "Error: Failed to create directory $BIN_DIR" >&2; return 1; }

  # --- Step 1: Remove existing container (ignore errors if not found) ---
  echo "1. Removing existing container '$CONTAINER_NAME' (if any)..."
  docker rm -fv "$CONTAINER_NAME" > /dev/null 2>&1 || true

  # --- Step 2: Build and Export Dagger Engine ---
  echo "2. Building engine from Dagger module '$DAGGER_MODULE'..."
  if ! dagger -m "$DAGGER_MODULE" call engine container export --path "$EXPORT_PATH"; then
    echo "Error: Dagger build failed for PR $PR_NUMBER." >&2
    # Optional cleanup of potentially partial tar file
    rm -f "$EXPORT_PATH"
    return 1
  fi
  echo "   Engine exported successfully to $EXPORT_PATH"

  # --- Step 3: Load Image and Extract SHA ---
  echo "3. Loading image from $EXPORT_PATH..."
  local load_output
  # Capture stdout from docker load
  if ! load_output=$(docker load -i "$EXPORT_PATH"); then
    echo "Error: Failed to load image from $EXPORT_PATH" >&2
    rm -f "$EXPORT_PATH" # Clean up tar file on failure
    return 1
  fi

  # Extract the SHA - looking for the line "Loaded image ID: sha256:..."
  # Using sed to extract the SHA part after 'sha256:'
  local SHA=$(echo "$load_output" | sed -n 's/^Loaded image ID: sha256:\([0-9a-f]\{64\}\).*/\1/p')

  # Validate SHA extraction
  if [[ -z "$SHA" ]]; then
    echo "Error: Could not extract image SHA from docker load output:" >&2
    echo "$load_output" >&2
    rm -f "$EXPORT_PATH" # Clean up tar file
    return 1
  fi
  echo "   Successfully loaded image ID: sha256:$SHA"

  # Clean up the exported tar file now that it's loaded
  echo "   Cleaning up temporary file $EXPORT_PATH..."
  rm -f "$EXPORT_PATH"

  # --- Step 4: Run the Container ---
  echo "4. Running container '$CONTAINER_NAME' using image sha256:$SHA..."
  if ! docker run --rm --privileged -d -v "$DOCKER_VOLUME" --name "$CONTAINER_NAME" "$SHA"; then
    echo "Error: Failed to run container '$CONTAINER_NAME' with image $SHA." >&2
    # Note: The image is still loaded in Docker. Manual cleanup might be needed.
    return 1
  fi

  # --- Step 5: Build the CLI ---
  echo "5. Building CLI..."
  if ! dagger -m "$DAGGER_MODULE" call cli binary --platform darwin/arm64 export --path "$BIN_PATH"; then
    echo "Error: Dagger CLI build failed for PR $PR_NUMBER." >&2
    # Optional cleanup of potentially partial tar file
    rm -f "$BIN_PATH"
    return 1
  fi

  echo "--- Successfully started container '$CONTAINER_NAME' for PR #$PR_NUMBER ---"
  echo "You can view its logs with: docker logs -f $CONTAINER_NAME"
  echo "Connect to this engine with _EXPERIMENTAL_DAGGER_RUNNER_HOST=docker-container://dagger-dev ~/bin/dagger"

  return 0 # Indicate success
}

# Set different OpenAI compatible endpoint configurations
use_openai() {
  export OPENAI_MODEL="op://Employee/OPENAI_DAGGER/model"
  export OPENAI_API_KEY="op://Employee/OPENAI_DAGGER/apikey"
  unset OPENAI_BASE_URL
  unset OPENAI_DISABLE_STREAMING
}

use_ollama() {
  export OPENAI_BASE_URL="op://Employee/OLLAMA_HOST/hostname"
  export OPENAI_MODEL="op://Employee/OLLAMA_HOST/model"
  unset OPENAI_DISABLE_STREAMING
  unset OPENAI_API_KEY
}

use_docker() {
  export OPENAI_BASE_URL="http://model-runner.docker.internal/engines/v1/"
  export OPENAI_MODEL="ai/qwen2.5"
  unset OPENAI_API_KEY
}


export GEMINI_API_KEY="op://Employee/GEMINI_API_KEY/credential"
export ANTHROPIC_API_KEY="op://Employee/Dagger Anthropic/credential"

