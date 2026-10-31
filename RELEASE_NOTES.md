Unpublished standalone manager 0.1.1 candidate

Requires UE4SS only. Removed framework startup/API, shared renderer and PCL menu-asset dependencies. The panel uses a stock game frame and manager-local services/tabs. Creative menu base remains in BladesongModFramework.

Framework installation is resolved only for selected mods that declare it. Added portable standalone metadata, metadata-first capability planning, exact-executable checks for raw integrations, and unused-framework removal with dependency protection. Bootstrap packages and CI no longer include or build the framework. Legacy combined Mods buttons are safely collapsed.

Automated tests pass; stock-game-widget behavior still needs live verification. No release publication is authorized.
