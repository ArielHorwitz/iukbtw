#! /bin/bash
set -e

CONFIG_DIR="$HOME/.config/openartist"
KEY_FILE="$CONFIG_DIR/apikey"
QUERY_FILE="$CONFIG_DIR/query"
EDITOR_QUERY_BLURB='Enter your prompt here, then save and close your editor. Leave empty to cancel.'
OUTPUT_DIR="$CONFIG_DIR/images"
RESPONSE_DATA_FILE="$CONFIG_DIR/last-response-data"
RESPONSE_HEADERS_FILE="$CONFIG_DIR/last-response-headers"

API_ENDPOINT="https://api.openai.com/v1/images/generations"
MODEL="dall-e-3"
REVISION_BYPASS="I NEED to test how the tool works with extremely simple prompts. DO NOT add any detail, just use it AS-IS:

"

APP_NAME=$(basename "$0")
ABOUT="Generate image using DALL·E 3."
CLI=(
    --prefix "args_"
    -O "prompt;Prompt text;;p"
    -O "image_name;Name of image;;n"
    -O "resolution;Resolution of image [(s)quare, (v)ertical, (h)orizontal];s;r"
    -O "style;Image style [vivid, natural];vivid;s"
    -O "quality;Image quality [hd, standard];hd;u"
    -f "list;List downloaded files;;l"
    -f "quiet;Be quiet (overrides --verbose);;q"
    -f "verbose;Be verbose;;v"
    -f "noopen;Do not open the file after downloading;;N"
    -f "allow_revision;Do not attempt to bypass the prompt revision;;R"
    -f "output_dir;Print download directory;;O"
)
CLI=$(spongecrab --name "$APP_NAME" --about "$ABOUT" "${CLI[@]}" -- "$@") || exit 1
# echo "$CLI"
eval "$CLI" || exit 1

# Parse verbosity
if [[ -n $args_quiet ]]; then
    VERBOSITY=0
elif [[ -n $args_verbose ]]; then
    VERBOSITY=2
else
    VERBOSITY=1
fi

# Create config directories
[[ -d $CONFIG_DIR ]] || mkdir --parents $CONFIG_DIR
[[ -d $OUTPUT_DIR ]] || mkdir --parents $OUTPUT_DIR


# Short operations
if [[ -n $args_list ]]; then
    find $OUTPUT_DIR -name "*.png" -type f | sort
    exit 0
elif [[ -n $args_output_dir ]]; then
    echo $OUTPUT_DIR
    exit 0
fi

# API key
OPENAI_API_KEY="$(cat $KEY_FILE)"

# Image style
if [[ ! $args_style = vivid && ! $args_style = natural ]]; then
    exit_error "Invalid style: $args_style (see --help)"
fi

# Image quality
if [[ ! $args_quality = hd && ! $args_quality = standard ]]; then
    exit_error "Invalid quality: $args_quality (see --help)"
fi

# Image size
if [[ $args_resolution = square || $args_resolution = s ]]; then
    image_size="1024x1024"
elif [[ $args_resolution = horizontal || $args_resolution = h ]]; then
    image_size="1792x1024"
elif [[ $args_resolution = vertical || $args_resolution = v ]]; then
    image_size="1024x1792"
else
    exit_error "Invalid resolution (see --help)"
fi

# Prompt
if [[ -n $args_prompt ]]; then
    query_content="$args_prompt"
else
    [[ -n $EDITOR ]] || exit_error "No editor configured (use EDITOR environment variable)"
    [[ $VERBOSITY -lt 1 ]] || printcolor -s notice "Reading query from editor: \"$EDITOR\"" >&2
    [[ -f $QUERY_FILE && -n $(< $QUERY_FILE) ]] || echo $EDITOR_QUERY_BLURB > $QUERY_FILE
    `$EDITOR $QUERY_FILE` &>/dev/null
    query_content="$(cat $QUERY_FILE)"
    [[ -n $query_content ]] || exit_error "Query content is empty"
fi

if [[ -z $args_allow_revision ]]; then
    query_content="${REVISION_BYPASS}${query_content}"
fi

if [[ $VERBOSITY -ge 2 ]]; then
    echo "$query_content"
fi


# Image name
if [[ -n $args_image_name ]]; then
    image_name=$args_image_name
else
    printcolor -f yellow -on "Image name: "
    read image_name
fi

# Generate image call data
json_template='{
    "model": $model,
    "prompt": $prompt,
    "n": 1,
    "size": $size,
    "quality": $quality,
    "style": $style
}'
jq_args=(
    --arg model $MODEL
    --arg prompt "$query_content"
    --arg size $image_size
    --arg quality $args_quality
    --arg style $args_style
)
json_calldata=$(jq -n "${jq_args[@]}" "$json_template")
curl_args=(
    -H "Content-Type: application/json"
    -H "Authorization: Bearer $OPENAI_API_KEY"
    -o "$RESPONSE_DATA_FILE"
    -D "$RESPONSE_HEADERS_FILE"
    -d "$json_calldata"
    -L
)
[[ $VERBOSITY -ge 2 ]] || curl_args+=(-sS)

# Generate image API call
[[ $VERBOSITY -lt 1 ]] || printcolor -s ok "Generating image..."
curl "${curl_args[@]}" $API_ENDPOINT
revised_prompt=$(jq -r '.data[].revised_prompt' "$RESPONSE_DATA_FILE")
url=$(jq -r '.data[].url' "$RESPONSE_DATA_FILE")
timestamp="$(date +%y-%m-%d--%H-%M-%S)"
filename="$OUTPUT_DIR/${image_name}_${timestamp}.png"

# Print
if [[ $VERBOSITY -ge 2 ]]; then
    bat $RESPONSE_HEADERS_FILE
    bat -l json $RESPONSE_DATA_FILE
    printcolor -s notice "Revised prompt:"
    echo "$revised_prompt"
fi

# Download image
[[ $VERBOSITY -lt 1 ]] || printcolor -s ok "Downloading image..."
curl_args=(-L -o "$filename")
[[ $VERBOSITY -ge 2 ]] || curl_args+=(-sS)
curl "${curl_args[@]}" "$url"

# Print and open
[[ $VERBOSITY -lt 1 ]] || echo $filename
[[ -n $args_noopen ]] || xdg-open "$filename" &
