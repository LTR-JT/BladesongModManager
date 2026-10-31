Unpublished standalone manager 0.1.3 candidate

Explicitly enable input on the stock manager page container and set SelfHitTestInvisible so its child controls remain clickable. Decorative stock-widget defaults no longer suppress the whole manager input tree. Added a regression with inherited disabled/hit-test-invisible defaults and diagnostic logging of those inherited values.

The manager requires UE4SS only. The optional framework remains responsible for shared Creative UI and SDK game compatibility. Previous native-proxy button visibility fix is retained. Live in-game verification is pending; no release is authorized.
