use anyhow::{anyhow, Result};
use clap::Args;
use commander::{DBUS_NAME, run_from_command};
use dbus::channel::MatchingReceiver;
use dbus::message::MatchRule;
use dbus_crossroads::Crossroads;
use dbus_tokio::connection;
use futures::future;

#[derive(Debug, Args)]
pub struct Cli {}

struct State;

#[tokio::main]
pub async fn main() -> Result<()> {
    let (resource, dbus_conn) = connection::new_session_sync()?;
    let _handle = tokio::spawn(async {
        let err = resource.await;
        anyhow!("Lost connection to D-Bus: {err}")
    });
    dbus_conn.request_name(DBUS_NAME, false, true, false).await?;
    let mut cross = Crossroads::new();
    cross.set_async_support(Some((
        dbus_conn.clone(),
        Box::new(|x| {
            tokio::spawn(x);
        }),
    )));
    let interface_token = cross.register(DBUS_NAME, |dbus| {
        // Arbitrary command
        dbus.method_with_cr_async(
            "command",
            ("command",),
            ("errors",),
            |mut ctx, _cr, (command,): (String,)| {
                async move {
                    println!("Command received: {command}");
                    match run_from_command(command.as_str()) {
                        Ok(_) => ctx.reply(Ok(("success".to_owned(),))),
                        Err(e) => ctx.reply(Ok((e.to_string(),))),
                    }
                }
            },
        );
        // Shutdown
        dbus.method_with_cr_async(
            "shutdown",
            (),
            ("success",),
            |_ctx, _cr, _: ()| {
                async move {
                    // Reply
                    #![allow(clippy::panic)]
                    panic!("Server shutdown");
                    #[allow(unreachable_code)]
                    _ctx.reply(Ok(("Shutting down",)))
                }
            },
        );
    });
    // Register interface token
    cross.insert("/", &[interface_token], State);
    // Start listening
    dbus_conn.start_receive(
        MatchRule::new_method_call(),
        Box::new(move |msg, conn| {
            cross.handle_message(msg, conn).expect("handle message");
            true
        }),
    );
    println!("Running iuk server.");
    future::pending::<()>().await;
    unreachable!()
}
