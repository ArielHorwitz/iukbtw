use anyhow::{anyhow, Result};
use clap::Parser;
use std::process::{Command, Stdio};

#[derive(Clone, Debug)]
pub struct CommandOutput {
    pub stdout: String,
    pub stderr: Option<String>,
}

/// Run command and return stdout and stderr
pub fn run_capture_output(cmd: &mut Command) -> Result<CommandOutput> {
    let output = cmd.output().map_err(|err| anyhow!(err))?;
    let stdout = String::from_utf8(output.stdout).map_err(|err| anyhow!(err))?;
    let stderr = String::from_utf8(output.stderr).map_err(|err| anyhow!(err))?;
    let stderr = match stderr.len() {
        0 => None,
        _ => Some(stderr),
    };
    Ok(CommandOutput { stdout, stderr })
}

/// Run command and return stdout as Ok variant and stderr as Err variant
pub fn run(cmd: &mut Command) -> Result<String> {
    let result = run_capture_output(cmd)?;
    match result.stderr {
        Some(stderr) => Err(anyhow!("{stderr} [command: {cmd:?}]")),
        None => Ok(result.stdout),
    }
}

/// Run command and forward stdout and stderr
#[allow(dead_code)]
pub fn run_nocapture_output(cmd: &mut Command) {
    match run_capture_output(cmd) {
        Err(stderr) => eprint!("{stderr}"),
        Ok(output) => {
            print!("{}", output.stdout);
            if let Some(stderr) = output.stderr {
                eprint!("{}", stderr);
            }
        }
    };
}

pub fn resolve(args: Args) -> Result<()> {
    Command::new("bash")
        .arg("-c")
        .arg(args.command)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .spawn()?;
    Ok(())
}

/// Run arbitrary external command
///
/// Command is run via a spawned bash process. Standard I/O is blocked.
#[derive(Debug, Parser)]
pub struct Args {
    /// Full command
    #[arg(value_name = "COMMAND")]
    command: String,
}