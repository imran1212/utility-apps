# Architecture

Every directory under `apps/` is an independent product and Play Store listing. Each app owns its application ID, display name, launcher icon, assets, and app-specific features.

Reusable packages live under `packages/`:
- common_ui: shared Material 3 theme
- ad_manager: AdMob initialization and banner widget
- premium_manager: premium entitlement abstraction
- storage_manager: local preferences
- image_engine: on-device image compression

Apps may depend on shared packages; shared packages must never depend on apps. Keep the dependency graph acyclic and analyze the workspace after shared changes.
