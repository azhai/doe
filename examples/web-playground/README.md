## Doe Web Playground Example

This example shows how you can embed the Doe interpreter into your webpage with an editor. It uses codemirror for the editor.

## Getting started.

Make sure you have built `doe.wasm` in [Building](https://github.com/azhai/doe/blob/master/docs/build.md) or downloaded from [Downloads](https://github.com/azhai/doe/releases).

Copy doe.wasm into this directory.

Start a local file server in this directory:
```sh
python3 -m http.server 8000
```

Open your browser and visit `http://localhost:8000/index.html`
