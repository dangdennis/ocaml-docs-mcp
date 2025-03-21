# OCaml MCP - Model Context Protocol Server for OCaml Documentation

OCaml MCP is a WIP server implementation that integrates with the OCaml documentation system to provide documentation data to AI assistants through the Model Context Protocol (MCP). 

## Overview

OCaml MCP bridges the gap between OCaml's documentation and AI assistants with a simple, powerful server. It:

- Delivers OCaml package docs directly to AI assistants via the Model Context Protocol
- Offers both RESTful endpoints and an MCP-compatible JSON-RPC interface
- Pulls package information straight from OCaml.org's documentation repository

This direct access to library documentation helps LLMs give you more accurate OCaml coding assistance.

OCaml.org doesn't provide a JSON API, so our server acts as a smart proxy, fetching and forwarding documentation files from URLs like:
> https://docs-data.ocaml.org/live/p/fmt/0.10.0/status.json
> https://docs-data.ocaml.org/live/p/fmt/0.10.0/index.js

## Roadmap

Get the latest version of a package without requiring an explicit version.

## Features

- **Package Information Retrieval**: Access full documentation for any OCaml package available in the documentation system
- **Package Status Information**: Check the status of OCaml packages
- **Raw JavaScript Content**: Returns the full content of the documentation's JS file, allowing LLMs to parse the rich information themselves
- **Dual API**: Both RESTful and JSON-RPC interfaces are available
- **Built with OCaml 5**: Leverages Eio for concurrent I/O

## Installation

### Prerequisites

- OCaml 5.x or higher
- Opam (OCaml Package Manager)
- Dune build system

### Installation from Source

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/ocaml_mcp.git
   cd ocaml_mcp
   ```

2. Install dependencies:
   ```
   opam install . --deps-only
   ```

3. Build the project:
   ```
   dune build
   ```

## Running the Server

Start the server on the default port (8080):

```
dune exec ocaml_mcp
```

The server will display:
```
Starting MCP server on http://localhost:8080
Press Ctrl+C to stop the server
```

## API Usage

### RESTful API

#### Get Package Information

```
GET /packages/{package_name}/{version}/info
```

Example:
```bash
curl -X GET "http://localhost:8080/packages/fmt/0.10.0/info"
```

#### Get Package Status

```
GET /packages/{package_name}/{version}/status
```

Example:
```bash
curl -X GET "http://localhost:8080/packages/fmt/0.10.0/status"
```

### MCP JSON-RPC API

The MCP endpoint is available at:
```
POST /mcp
```

#### Get Package Information

Example:
```bash
curl -X POST "http://localhost:8080/mcp" \
  -H "Content-Type: application/json" \
  -d '{"id": "1", "method": "getPackageInfo", "params": {"packageName": "fmt", "version": "0.10.0"}}'
```

#### Get Package Status

Example:
```bash
curl -X POST "http://localhost:8080/mcp" \
  -H "Content-Type: application/json" \
  -d '{"id": "1", "method": "getStatus", "params": {"packageName": "fmt", "version": "0.10.0"}}'
```

## Integrating with AI Assistants

OCaml MCP is designed to work with AI assistants that support the Model Context Protocol. The raw documentation data is returned in a format that LLMs can parse and interpret to provide more accurate assistance with OCaml code.

## Development

### Project Structure

- `bin/`: Contains the main executable code
- `lib/`: Core library functionality
  - `client.ml`: HTTP client for fetching documentation
  - `server.ml`: Server implementation
  - `types.ml`: Type definitions
  - `sdk.ml`: SDK for client applications

### Building for Development

```
dune build --watch
```

### Running Tests

```
dune runtest
```

## License

This project is licensed under the terms specified in the LICENSE file.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
