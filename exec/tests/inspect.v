From FreeSpec Require Import Exec Debug.
From Coq Require Import String.

#[local] Open Scope string_scope.

Generalizable All Variables.

Definition inspect `{Provide ix DEBUG} : impure ix string :=
  do inspect "hi, dear.";
     var x <- iso true in
     inspect x
  end.

Exec inspect.
