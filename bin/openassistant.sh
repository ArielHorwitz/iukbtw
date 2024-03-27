#! /bin/bash
set -e

# Configuration files
CONFIG_DIR="$HOME/.config/openassistant"
KEY_FILE="$CONFIG_DIR/apikey"
MODEL_SETTINGS_FILE="$CONFIG_DIR/model_settings"
SYS_INSTR_DIR="$CONFIG_DIR/system_instructions"
LOCAL_DIR="$HOME/.local/share/openassistant"
HISTORY_DIR="$LOCAL_DIR/history"
STATS_FILE_TOTALS="$LOCAL_DIR/stats"
# Current conversation files
CONVO_DIR="$LOCAL_DIR/.current"
SYS_INSTR_FILE="$CONVO_DIR/system_instructions"
QUERY_FILE="$CONVO_DIR/query"
CALLDATA_FILE="$CONVO_DIR/calldata"
RESPONSE_DATA_FILE="$CONVO_DIR/response_data"
RESPONSE_HEADERS_FILE="$CONVO_DIR/response_headers"
RESPONSE_CONTENT_FILE="$CONVO_DIR/response_content"
STATS_FILE_CURRENT="$CONVO_DIR/stats"
# Defaults
API_URL="https://api.openai.com/v1/chat/completions"
DEFAULT_MODEL_SETTINGS='# For details see: https://platform.openai.com/docs/api-reference/chat
model: "gpt-4-turbo-preview"
max_tokens: 4096
temperature: 1.0
top_p: 1.0
frequency_penalty: .05
presence_penalty: .01'
DEFAULT_SYSTEM_INSTRUCTIONS='You are a helpful assistant. Format your responses in markdown.'
EDITOR_QUERY_BLURB='Enter your prompt here, then save and close your editor. Leave empty to cancel.'
# Token costs are denominated in USD per token (https://openai.com/pricing)
TOKEN_COST_PROMPT=0.00001
TOKEN_COST_RESPONSE=0.00003

# Generate tree structure
[[ -d $CONFIG_DIR ]] || mkdir --parents $CONFIG_DIR
[[ -d $SYS_INSTR_DIR ]] || mkdir --parents $SYS_INSTR_DIR
[[ -d $HISTORY_DIR ]] || mkdir --parents $HISTORY_DIR
[[ -d $CONVO_DIR ]] || mkdir --parents $CONVO_DIR
# Create defaults
[[ -f $KEY_FILE ]] || echo "sk-YOUR_OPENAI_API_KEY" > $KEY_FILE
[[ -f $MODEL_SETTINGS_FILE ]] || echo "$DEFAULT_MODEL_SETTINGS" > $MODEL_SETTINGS_FILE
[[ -f $SYS_INSTR_DIR/default ]] || echo $DEFAULT_SYSTEM_INSTRUCTIONS > $SYS_INSTR_DIR/default
[[ -f $STATS_FILE_TOTALS ]] || echo "No recorded stats." > $STATS_FILE_TOTALS

# Wrapper for error handling
EXIT_ERROR="`which exit_error`"
exit_error() {
    cleanup
    `$EXIT_ERROR "$@"`
}

APP_NAME=$(basename "$0")
ABOUT='Query your personal OpenAI assistant.

Write your OpenAI API key in the configuration folder (--config-dir).'
CLI=(
    --prefix "args_"
    -o "quick-load;Quietly load a conversation index (see --load --quiet);;."
    -O "preset;Instructions preset;default;p"
    -O "history;Conversation history: (Y)es, (N)o, ask-(y)es, ask-(n)o;ask-yes;y"
    -O "load;Load a conversation index (see --list);;L"
    -O "delete;Delete a conversation index (see --list);;D"
    -O "list-offset;Index offset of conversations to show (see --list);0;O"
    -O "list-limit;Limit number of conversations to show (see --list);10;T"
    -f "list;List conversations from history;;l"
    -f "stats;Print recorded stats;;s"
    -f "config-dir;Print configuration directory path;;c"
    -f "history-dir;Print history directory path;;H"
    -f "quiet;Only print the response (overrides --verbose);;q"
    -f "verbose;Show debugging details;;v"
    -f "clear-data;Delete all recorded data and history;;C"
    -f "clear-config;Delete all configuration data"
    -f "force;Do not ask for confirmation;;f"
    -f "read-stdin;Read from stdin instead of opening an editor;;I"
    -f "debug;Enabled verbose debugging"
)
CLI=$(spongecrab --name "$APP_NAME" --about "$ABOUT" "${CLI[@]}" -- "$@") || exit 1
eval "$CLI" || exit 1

get_api_key() {
    [[ -f $KEY_FILE ]] || exit_error "Missing OpenAI API key file: $KEY_FILE"
    openai_api_key="$(cat $KEY_FILE)"
    [[ -n $openai_api_key ]] || exit_error "Empty OpenAI API key: $KEY_FILE"
}

get_model_setting() {
    local stat_name="$1"
    local line=$(grep -E "^${stat_name}: " $MODEL_SETTINGS_FILE) || exit_error "Missing model setting: $stat_name. Delete $MODEL_SETTINGS_FILE to regenerate defaults."
    printf "%s" "${line#${stat_name}: }"
}

get_system_instructions() {
    if [[ ! -f $SYS_INSTR_FILE ]]; then
        local file="$SYS_INSTR_DIR/$args_preset"
        [[ -f $file ]] || exit_error "No such preset: $args_preset"
        cp "$file" $SYS_INSTR_FILE
    fi
    system_instructions="$(cat $SYS_INSTR_FILE)"
}

get_query() {
    query_content="$(cat $QUERY_FILE)"
    [[ -n $query_content ]] || exit_error "Query content is empty"
}

read_query_to_file() {
    if [[ -n $args_read_stdin ]]; then
        [[ -n $QUIET ]] || printcolor -s notice "Reading query from stdin..." >&2
        read query_content
        echo "$query_content" > $QUERY_FILE
    else
        [[ -n $EDITOR ]] || exit_error "No editor configured (use EDITOR environment variable)"
        [[ -z $VERBOSE ]] || printcolor -s notice "Reading query from editor: \"$EDITOR\"" >&2
        [[ -f $QUERY_FILE && -n $(< $QUERY_FILE) ]] || echo $EDITOR_QUERY_BLURB > $QUERY_FILE
        `$EDITOR $QUERY_FILE` &>/dev/null
    fi
}

generate_call_data() {
    local json_template='{
    messages: [
        {
            role: "system",
            content: $system_instructions
        },
        {
            role: "user",
            content: $query_content
        }
    ],
    model: $model,
    top_p: $top_p,
    max_tokens: $max_tokens,
    temperature: $temperature,
    frequency_penalty: $frequency_penalty,
    presence_penalty: $presence_penalty
}'
    local jq_args=(
        --arg system_instructions "$system_instructions"
        --arg query_content "$query_content"
        --argjson model $(get_model_setting model)
        --argjson max_tokens $(get_model_setting max_tokens)
        --argjson temperature $(get_model_setting temperature)
        --argjson top_p $(get_model_setting top_p)
        --argjson frequency_penalty $(get_model_setting frequency_penalty)
        --argjson presence_penalty $(get_model_setting presence_penalty)
    )
    api_call_data=$(jq -n "${jq_args[@]}" "$json_template")
    echo "$api_call_data" > $CALLDATA_FILE
}

call_api() {
    local curl_args=(
        "$API_URL"
        --silent --show-error
        -o "$RESPONSE_DATA_FILE"
        -D "$RESPONSE_HEADERS_FILE"
        -H "Content-Type: application/json"
        -H "Authorization: Bearer $openai_api_key"
        -d "$api_call_data"
    )
    printcolor -ns ok "Fetching response..."
    curl "${curl_args[@]}" || :
    printf         '\r                    \r'
}

read_response() {
    local raw_response=$(jq -r '.choices.[0].message.content' "$RESPONSE_DATA_FILE" || echo '')
    if [[ -n $raw_response ]]; then
        echo "$raw_response" > $RESPONSE_CONTENT_FILE
        return 0
    fi
    printcolor -f yellow -o b,u "Error:" >&2
    jq --color-output < "$RESPONSE_DATA_FILE" >&2
    exit_error "$(jq -r '.error.message' $RESPONSE_DATA_FILE)"
}

print_response() {
    if [[ -n $VERBOSE ]]; then
        printcolor -f green -o b,u "Response headers:"
        bat -pp "$RESPONSE_HEADERS_FILE"
    fi
    [[ -n $QUIET ]] || printcolor -f green -o b,u "OpenAssistant says:"
    bat -pp --language markdown $RESPONSE_CONTENT_FILE
    if [[ -z $QUIET ]]; then
        local cost=$(get_stat_current cost)
        local tokens=$(get_stat_current tokens)
        local tokens_prompt=$(get_stat_current tokens_prompt)
        local tokens_response=$(get_stat_current tokens_response)
        local cost_prompt=$(get_stat_current cost_prompt)
        local cost_response=$(get_stat_current cost_response)
        printcolor -f cyan -n -ob "$tokens tokens ~\$$cost"
        printcolor -f cyan -ob -od " [prompt: $tokens_prompt ~\$$cost_prompt] [response: $tokens_response ~\$$cost_response]"
    fi
}

get_stat_global() {
    local stat_name="$1"
    local default
    [[ -n $2 ]] && default="$2" || default=0
    local line=$(grep -E "^${stat_name}: " $STATS_FILE_TOTALS || echo "$stat_name: $default")
    echo ${line#${stat_name}: }
}

get_stat_current() {
    local stat_name="$1"
    local default=0
    local line=$(grep -E "^${stat_name}: " $STATS_FILE_CURRENT || echo "$stat_name: $default")
    echo ${line#${stat_name}: }
}

tally_stats() {
    local tokens=$(jq '.usage.total_tokens' "$RESPONSE_DATA_FILE")
    local tokens_prompt=$(jq '.usage.prompt_tokens' "$RESPONSE_DATA_FILE")
    local tokens_response=$(jq '.usage.completion_tokens' "$RESPONSE_DATA_FILE")
    local cost_prompt=$(echo "scale=4;$tokens_prompt * $TOKEN_COST_PROMPT" | bc)
    local cost_response=$(echo "scale=4;$tokens_response * $TOKEN_COST_RESPONSE" | bc)
    local cost=$(echo "scale=4;$cost_prompt + $cost_response" | bc)
    echo \
"STATS - QUERY
cost: $cost
tokens: $tokens
tokens_prompt: $tokens_prompt
tokens_response: $tokens_response
cost_prompt: $cost_prompt
cost_response: $cost_response" \
    > $STATS_FILE_CURRENT
    echo \
"STATS - TOTALS
start: $(get_stat_global start `date +%y-%m-%d-%H-%M-%S`)
cost: $(echo $cost + `get_stat_global cost` | bc)
tokens: $(echo $tokens + `get_stat_global tokens` | bc)
tokens_prompt: $(echo $tokens_prompt + `get_stat_global tokens_prompt` | bc)
tokens_response: $(echo $tokens_response + `get_stat_global tokens_response` | bc)
cost_prompt: $(echo $cost_prompt + `get_stat_global cost_prompt` | bc)
cost_response: $(echo $cost_response + `get_stat_global cost_response` | bc)" \
    > $STATS_FILE_TOTALS
}

save_history() {
    case $save_history_enabled in
        1   ) : ;;
        ay  ) promptconfirm -t 30 "Save history?" || return 0 ;;
        an  ) promptconfirm -d "Save history?" || return 0 ;;
        *   ) return 0 ;;
    esac
    local convo_dir="$HISTORY_DIR/`date +%y-%m-%d-%H-%M-%S`"
    local history_files=(
        $SYS_INSTR_FILE
        $QUERY_FILE
        $CALLDATA_FILE
        $RESPONSE_DATA_FILE
        $RESPONSE_HEADERS_FILE
        $RESPONSE_CONTENT_FILE
        $STATS_FILE_CURRENT
    )
    mkdir --parents $convo_dir
    cp -t $convo_dir ${history_files[@]}
}

cleanup() {
    local delete_files=(
        $SYS_INSTR_FILE
        $CALLDATA_FILE
        $RESPONSE_DATA_FILE
        $RESPONSE_HEADERS_FILE
        $RESPONSE_CONTENT_FILE
        $STATS_FILE_CURRENT
    )
    rm -f ${delete_files[@]}
}

clear_data() {
    if [[ -z $args_force ]]; then
        promptconfirm -d "Clear all recorded stats and history?" || exit_error "Aborted."
    fi
    rm -rf $HISTORY_DIR
    rm -f $STATS_FILE_TOTALS
}

clear_config() {
    if [[ -z $args_force ]]; then
        promptconfirm -d "Clear all configuration data?" || exit_error "Aborted."
    fi
    rm -rf $CONFIG_DIR
}

print_debug_prequery() {
    printcolor -f green -ob -ou "Environment:"
    printcolor -f green -n -od " Config dir: "; echo $CONFIG_DIR
    printcolor -f green -n -od "  Local dir: "; echo $LOCAL_DIR
    printcolor -f green -n -od "    API key: "; echo "${openai_api_key:0:8}..."
    printcolor -f green -ob -ou "System instructions:"
    printcolor -f yellow -od "$system_instructions"
}

print_debug_precall() {
    printcolor -f green -ob -ou "Request data:"
    jq --color-output <<< $api_call_data
}

print_query() {
    printcolor -f green -ob -ou "Query:"
    printf "%s\n" "$query_content" | bat -pp --language markdown
}

list_conversations() {
    ls -1 $HISTORY_DIR | sort -r
}

list_history() {
    local dirs
    local query_cols=$((`tput cols` - 31))
    local query_cap=$((query_cols - 2))
    mapfile dirs <<< `list_conversations`
    [[ ${#dirs[@]} -gt 0 ]] || return 0
    local start=$args_list_offset
    local end=$((args_list_limit + start))
    local max=${#dirs[@]}
    for ((index=start; index<=end && index<=max; index++)); do
        printcolor -f magenta -n -od "`printf %-3s $index` "
        local dir=`echo "$HISTORY_DIR/${dirs[index]}" | xargs`
        local fulldate=`basename $dir`
        printcolor -f blue -n -od "`printf '%-9s' ${fulldate:0:8}`"
        local dtime=`cut -d- -f4- <<< $fulldate | sed 's/-/:/g'`
        printcolor -f blue -n -od "`printf '%-9s' ${dtime:0:8}` "
        local ptokens=$(printf '%3s' $(wc -w "$dir/query" 2>&- | awk '{print $1}' || printf "??"))
        local rtokens=$(printf '%3s' $(wc -w "$dir/response_content" 2>&- | awk '{print $1}' || printf "??"))
        printcolor -f red -n -od "$ptokens "
        printcolor -f green -n -od "$rtokens "
        local query_line=$(tr '\n' ' ' < "$dir/query" || echo "??")
        [[ ${#query_line} -le $query_cols ]] || local query_line="${query_line:0:query_cap}.."
        printcolor -f cyan -n -od "$query_line"
        echo
    done
}

get_conversation() {
    local index=$1
    local dirs
    mapfile dirs <<< `list_conversations`
    local dirname=`echo "${dirs[index]}" | xargs`
    [[ -n $dirname ]] || return 1
    local dir="$HISTORY_DIR/$dirname"
    [[ -d $dir ]] || return 1
    echo $dir
}

load_from_history() {
    local dir=`get_conversation $args_load || exit_error "Unknown conversation index: $args_load"`
    [[ -n $QUIET ]] || printcolor -s notice "Loading conversation from: $dir"
    cp -t $CONVO_DIR "$dir"/*
}

delete_from_history() {
    local dir=$(get_conversation $args_delete || return 1) || exit_error "Unknown conversation index: $args_delete"
    [[ -n $QUIET ]] || printcolor -s notice "Deleting conversation from: $dir"
    rm -r $dir
}

flow_query_normal() {
    get_api_key
    get_system_instructions
    [[ -z $VERBOSE ]] || print_debug_prequery

    read_query_to_file
    get_query
    [[ -n $QUIET ]] || print_query

    generate_call_data
    [[ -z $VERBOSE ]] || print_debug_precall
    call_api
    read_response
    tally_stats

    print_response
    save_history
}

flow_query_from_history() {
    load_from_history
    get_system_instructions
    [[ -z $VERBOSE ]] || print_debug_prequery
    get_query
    [[ -n $QUIET ]] || print_query
    [[ -z $VERBOSE ]] || print_debug_precall
    print_response
}

# Start
[[ -z $args_debug ]] || set -x
if [[ -n $args_quick_load ]]; then
    args_quiet=1
    args_load=$args_quick_load
fi
if [[ -n $args_quiet ]]; then
    QUIET=1
    VERBOSE=
elif [[ -n $args_verbose ]]; then
    QUIET=
    VERBOSE=1
fi
case ${args_history} in
    n | ask-no     ) save_history_enabled="an" ;;
    y | ask-yes    ) save_history_enabled="ay" ;;
    Y | Yes | yes  ) save_history_enabled=1 ;;
    N | No | no    ) save_history_enabled= ;;
    *              ) exit_error "Invalid history option: $args_history" ;;
esac

cleanup
if [[ -n $args_list ]];            then list_history
elif [[ -n $args_config_dir ]];    then echo $CONFIG_DIR
elif [[ -n $args_history_dir ]];   then echo $HISTORY_DIR
elif [[ -n $args_stats ]];         then cat $STATS_FILE_TOTALS
elif [[ -n $args_delete ]];        then delete_from_history
elif [[ -n $args_clear_data ]];    then clear_data
elif [[ -n $args_clear_config ]];  then clear_config
elif [[ -n $args_load ]];    then flow_query_from_history
else flow_query_normal
fi
cleanup
