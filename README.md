# Rivalo — Apple Watch

App watchOS de Rivalo: captura del rendimiento físico durante un partido de fútbol amateur.

Permite iniciar, registrar en vivo (tiempo, ritmo cardíaco, distancia) y finalizar un partido.
Al terminar, la sesión se sincroniza con el iPhone para su resumen visual.

## Stack

- SwiftUI (watchOS)
- HealthKit (workout sessions)
- WatchConnectivity (sincronización con el iPhone)

## Repositorios del proyecto

- `rivalo-watch` — app Apple Watch (este repo)
- `rivalo-ios` — app iPhone
- `rivalo-server` — API backend

## Development

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen) and is not committed.

```bash
brew install xcodegen        # once
xcodegen generate            # creates RivaloWatch.xcodeproj
open RivaloWatch.xcodeproj
```

Building for the watchOS Simulator requires the watchOS platform component
(Xcode > Settings > Components). You can type-check the sources without it:

```bash
swiftc -typecheck -sdk "$(xcrun --sdk watchsimulator --show-sdk-path)" \
  -target arm64-apple-watchos10.0-simulator Sources/*.swift
```

## Estado

En desarrollo inicial.
