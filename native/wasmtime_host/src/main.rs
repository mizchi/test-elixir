use serde::{Deserialize, Serialize};
use std::env;
use std::error::Error;
use std::io::{self, Read, Write};
use wasmtime::{Engine, Instance, Module, Store, TypedFunc};

#[derive(Debug, Deserialize)]
struct Request {
    function: String,
    args: Vec<i32>,
}

#[derive(Debug, Serialize)]
#[serde(untagged)]
enum Response {
    Ok { ok: i32 },
    Error { error: String },
}

struct Runtime {
    add: TypedFunc<(i32, i32), i32>,
    fib: TypedFunc<i32, i32>,
    store: Store<()>,
}

impl Runtime {
    fn new(module_path: &str) -> Result<Self, Box<dyn Error>> {
        let engine = Engine::default();
        let wasm_bytes = wat::parse_file(module_path)?;
        let module = Module::new(&engine, wasm_bytes)?;

        let mut store = Store::new(&engine, ());
        let instance = Instance::new(&mut store, &module, &[])?;
        let add = instance.get_typed_func::<(i32, i32), i32>(&mut store, "add")?;
        let fib = instance.get_typed_func::<i32, i32>(&mut store, "fib")?;

        Ok(Self { add, fib, store })
    }

    fn handle(&mut self, request: Request) -> Response {
        match request.function.as_str() {
            "add" => match request.args.as_slice() {
                [left, right] => match self.add.call(&mut self.store, (*left, *right)) {
                    Ok(value) => Response::Ok { ok: value },
                    Err(error) => Response::Error {
                        error: error.to_string(),
                    },
                },
                _ => Response::Error {
                    error: "invalid_arguments".to_string(),
                },
            },
            "fib" => match request.args.as_slice() {
                [n] => match self.fib.call(&mut self.store, *n) {
                    Ok(value) => Response::Ok { ok: value },
                    Err(error) => Response::Error {
                        error: error.to_string(),
                    },
                },
                _ => Response::Error {
                    error: "invalid_arguments".to_string(),
                },
            },
            _ => Response::Error {
                error: "unsupported_function".to_string(),
            },
        }
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    let module_path = env::args().nth(1).ok_or("missing module path")?;
    let mut runtime = Runtime::new(&module_path)?;
    let mut reader = io::stdin().lock();
    let mut writer = io::stdout().lock();

    while let Some(frame) = read_frame(&mut reader)? {
        let response = match serde_json::from_slice::<Request>(&frame) {
            Ok(request) => runtime.handle(request),
            Err(_error) => Response::Error {
                error: "invalid_request".to_string(),
            },
        };

        write_frame(&mut writer, &serde_json::to_vec(&response)?)?;
    }

    Ok(())
}

fn read_frame(reader: &mut impl Read) -> io::Result<Option<Vec<u8>>> {
    let mut length_buffer = [0_u8; 4];

    match reader.read_exact(&mut length_buffer) {
        Ok(()) => {
            let length = u32::from_be_bytes(length_buffer) as usize;
            let mut payload = vec![0_u8; length];
            reader.read_exact(&mut payload)?;
            Ok(Some(payload))
        }
        Err(error) if error.kind() == io::ErrorKind::UnexpectedEof => Ok(None),
        Err(error) => Err(error),
    }
}

fn write_frame(writer: &mut impl Write, payload: &[u8]) -> io::Result<()> {
    writer.write_all(&(payload.len() as u32).to_be_bytes())?;
    writer.write_all(payload)?;
    writer.flush()
}
