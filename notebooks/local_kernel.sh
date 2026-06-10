#!/bin/bash

# Configuration
PID_FILE=".kernel.pid"
LOG_FILE=".kernel.log"
KERNEL_NAME="notebooks"
DISPLAY_NAME="Python (project/notebooks)"

# --- Function Definitions ---

# Installs dependencies and registers the kernel with Jupyter
kernel_install() {
    echo "📦 Installing ipykernel dependency..."
    uv add --dev ipykernel

    echo "🎫 Registering kernel configuration with Jupyter..."
    uv run python -m ipykernel install --user --name="$KERNEL_NAME" --display-name "$DISPLAY_NAME"
    echo "✅ Installation complete! The kernel '$DISPLAY_NAME' is registered."
}

# Launches the kernel in the background
kernel_start() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "⚠️  Kernel is already running! (PID: $(cat $PID_FILE))"
        return 1
    fi

    echo "🚀 Launching uv ipykernel in the background..."
    # Start the launcher and hide background messages inside the log file
    uv run python -m ipykernel_launcher > "$LOG_FILE" 2>&1 &

    # Save the background process ID
    echo $! > "$PID_FILE"
    echo "🟢 Kernel started successfully! (PID: $!)"
    echo "💡 Tip: Check '$LOG_FILE' if you need connection details."
}

# Safely shuts down the running kernel
kernel_stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "❌ No active kernel tracking file found."
        return 1
    fi

    PID=$(cat "$PID_FILE")
    
    # 1. Check if the process is alive
    if kill -0 "$PID" 2>/dev/null; then
        # 2. Safety Check: Ensure the PID actually belongs to uv or python
        local proc_name
        proc_name=$(ps -p "$PID" -o comm= 2>/dev/null)
        if [[ "$proc_name" != *"uv"* && "$proc_name" != *"python"* && "$proc_name" != *"python3"* ]]; then
            echo "🚨 Safety abort! PID $PID belongs to '$proc_name', not your kernel."
            echo "🗑️ Clearing out the stale tracking file safely."
            rm -f "$PID_FILE"
            return 1
        fi

        echo "🛑 Stopping the uv ipykernel and its sub-processes (PID: $PID)..."
        
        # 3. Kill the process group (using the minus sign) to clean up uv + python together
        kill -15 -"$PID" 2>/dev/null || kill -15 "$PID"
        
        # Loop until it fully exits
        while kill -0 "$PID" 2>/dev/null; do 
            sleep 0.5
        done
        echo "✨ Stopped cleanly."
    else
        echo "⚠️  Process ID $PID was tracked but is already dead."
    fi
    
    rm -f "$PID_FILE"
}

# Checks if the kernel is currently alive
kernel_status() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "🟢 Kernel is currently RUNNING. (PID: $(cat $PID_FILE))"
    else
        echo "🔴 Kernel is STOPPED."
    fi
}

# Prints out instructions if a wrong command is given
print_usage() {
    echo "Usage: $0 {install|start|stop|status}"
    return 1
}

# --- Main Script Execution ---
case "$1" in
    install) kernel_install ;;
    start)   kernel_start ;;
    stop)    kernel_stop ;;
    status)  kernel_status ;;
    *)       print_usage ;;
esac
