---
name: tmux
description: Manage background jobs, capture command output, and handle session multiplexing. Use when running long commands, capturing output from detached processes, or managing concurrent tasks in headless environments.
---

# tmux

Terminal multiplexer for background jobs, output capture, and session control.

## Quick Reference

| Command                               | Description                       |
| ------------------------------------- | --------------------------------- |
| `tmux new -d -s name 'cmd'`           | Run command in background session |
| `tmux capture-pane -t name -p`        | Capture session output            |
| `tmux send-keys -t name 'text' Enter` | Send input to session             |
| `tmux kill-session -t name`           | Kill session               	    |
| `tmux ls`                             | List sessions                	    |
| `tmux has -t name`                    | Check if session exists           |

## Running Background Processes

```bash
# Run command in new detached session
tmux new-session -d -s myserver 'python -m http.server 8080'

# With specific working directory
tmux new-session -d -s build -c /path/to/project 'make build'

# Keep session alive after command ends
tmux new-session -d -s task 'command; exec bash'

# Run only if session does not already exist
tmux has -t myserver || tmux new-session -d -s myserver 'command'
```

## Capturing Output

```bash
# Capture visible output
tmux capture-pane -t mysession -p

# Capture whole scrollback
tmux capture-pane -t mysession -p -S -

# Capture last N lines
tmux capture-pane -t mysession -p -S -100

# Save to file
tmux capture-pane -t mysession -p > output.txt

# Capture with escape sequences (colors)
tmux capture-pane -t mysession -p -e
```

## Sending Input

```bash
# Send text and press Enter
tmux send-keys -t mysession 'echo hello' Enter

# Send without Enter
tmux send-keys -t mysession 'some-text'

# Send Ctrl+C
tmux send-keys -t mysession C-c
```

## Session Management

```bash
# List sessions
tmux list-sessions
tmux ls

# Kill specific session
tmux kill-session -t myserver

# Kill all sessions
tmux kill-server

# Check whether session exists
tmux has -t mysession
```

## Wait for Completion

```bash
# Signal completion from command
tmux new-session -d -s job 'command; tmux wait-for -S job-done'

# Wait for signal
tmux wait-for job-done
```

## Common Patterns

### Development Servers

```bash
tmux new-session -d -s backend 'bun run backend'
tmux new-session -d -s frontend 'bun run frontend'
tmux new-session -d -s tests 'vitest --watch'
```

# Run and capture output

```bash
tmux new-session -d -s job 'command'
sleep 0.5
output=$(tmux capture-pane -t job -p)
echo "$output"
```

### Conditional session

```bash
tmux has -t myserver || tmux new-session -d -s myserver 'command'
```

### Clean up

```bash
tmux kill-session -t backend
tmux kill-session -t frontend
tmux kill-server  # Kill all
```

## Tips

- Use `tmux new-session -d` for background jobs
- Use `tmux capture-pane -p -S -` for whole scrollback
- Use `tmux has -t name` to check whether session exists
- Use `tmux kill-server` to clean up all sessions
- Use `-c /path` to set working directory
- Use `exec bash` to keep session alive after command
