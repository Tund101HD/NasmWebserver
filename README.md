# NasmWebserver

A static HTTP file server written in x86-64 assembly (NASM) for Linux. It uses no libc and no runtime: every socket, file and console operation is a raw `syscall`.
This project is inspired by [ymawky](https://github.com/imtomt/ymawky) on GitHub before it received its Linux port, since I wanted to get it to run on Linux too. 
If you hate your machine, you can expose this as a public server (which I do not recommend right now).

```
Please specify a port to run on
8080
[Info] Starting webserver at port 8080
[Debug] Succesfully bound to socket
[Debug] Now listening to connection
[Debug] A client has connected!
GET / 200
[Debug] A client has connected!
GET /css/style.css 200
[Debug] A client has connected!
GET /missing.html 404
```

## What it does as of right now

- Listens on a TCP port you enter at startup and handles one connection at a time
- Parses the request line and recognizes `GET`, `POST`, `PUT`, `DELETE`, `HEAD` and `TRACE`
- Serves files from the `www/` folder, including subfolders
- Maps `/` and any directory to its `index.html`
- Returns `404 Not Found` for missing files and `403 Forbidden` for paths containing `..`
- Sends file bodies with `sendfile`, so the kernel copies the file straight to the socket
- Logs each request as `METHOD PATH STATUS`

## Its current application flow

Startup (`main.nasm`):

1. `openat` the doc root once with `O_DIRECTORY` and keep the fd in `root_fd`
2. Read the port from stdin and convert it with `atoi`
3. `socket` → `bind` → `listen`, then loop on `accept`

Per request (`http.nasm`):

```
read request → parse method and path (reject "..")
      │
openat(root_fd, path) ──fails──→ 404
      │
fstat ──directory──→ openat(dir_fd, "index.html") and check again
      │ regular file
write status line + headers
      │
sendfile(client, file, size) until all bytes are sent
      │
close file → close client
```

Each file is opened relative to `root_fd` with the leading `/` stripped. That way the path can't escape the doc root through an absolute path.

| File | Contents |
|---|---|
| `main.nasm` | entry point `_start`, doc root, socket setup, accept loop |
| `http.nasm` | request parsing, file lookup, response, request logging |
| `utils.nasm` | console I/O, `atoi`, `itoa` |
| `www/` | sample site to serve |

Syscalls used: `read` (0), `write` (1), `close` (3), `fstat` (5), `sendfile` (40), `socket` (41), `accept` (43), `bind` (49), `listen` (50), `exit` (60), `openat` (257).

## Building

You need Linux on x86-64 (WSL works) with `nasm` and `ld`:

```bash
sudo apt install nasm binutils
```

### With nasm and ld directly

```bash
for f in main http utils; do nasm -f elf64 -g -F dwarf -o $f.o $f.nasm; done
ld -o webserver main.o http.o utils.o
```

### With CMake (also what CLion uses)

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

The binary ends up at `build/AssemblyWebserver`. `CMakeLists.txt` assembles every `*.nasm` file in the folder and links it with `-nostdlib -no-pie`. 
CMake also needs a C compiler, which it only uses as the linker driver. On Windows, use a WSL toolchain in CLion. For CLion specifically, feel
free to check out my [plugin](https://github.com/Tund101HD/clion-assembly-plugin) for assembly support which helped massively during 
development of this and makes setting this up easy.

## Running

**First set the doc root.** It's an absolute path in `main.nasm`:

```nasm
server_root db "/path/to/NasmWebserver/www", 0x00
```

Change it to where `www/` is on your machine and rebuild. If the path is wrong, the server exits immediately with status 1.

Then start it and type a port:

```bash
./webserver
```

Test from a second terminal:

```bash
curl -i http://localhost:8080/
```

## Limitations (what i haven't added yet)

These are known and are part of the to-do list:

- **No `Content-Type` or `Content-Length` header yet.** Successful responses send only `Connection: close`, so the browser guesses the type and reads until the connection closes.
- One connection at a time, no keep-alive, no timeouts
- The request is read with a single `read` of at most 1024 bytes
- No URL decoding, and `?query` strings aren't stripped
- `HEAD` gets a body; every other method is served like `GET`
- The doc root path is hardcoded
- Errors from `socket`, `bind` and `listen` are compared with `-1`, but raw syscalls return `-errno`, so most failures aren't caught

## Next steps

- [ ] `Content-Type` from the file extension and `Content-Length` from `fstat`
- [ ] No body for `HEAD`, `405 Method Not Allowed` for other methods
- [ ] Doc root and port as command-line arguments
- [ ] Correct `-errno` checks on startup
- [ ] URL decoding
- [ ] Requests larger than 1024 bytes

## License

MIT, see [LICENSE](LICENSE).
