From FreeSpec Require Import Core Notations.
From Prelude Require Import Integer State Tactics.
From Coq Require Import ZArith.

Generalizable All Variables.

(** This library introduces the starting point of the FreeSpec framework, that
    is the original the original example which motivates everything else. *)

(** * The Verification Problem *)

(** We model a small subset of a x86 architecture, where a Memory Controller
    (now integrated into the CPU die) received memory accesses from cores, and
    dispatches these accesses to differont controllers.  In our case, we only
    consider the DRAM and VGA controllers.

    From a FreeSpec perspective, we therefore consider three components and as
    many interfaces, whith the memory controller exposing its own interfaces and
    relying on the interfaces of the two other controllers.

    The DRAM contains a special-purpose memory region called the SMRAM,
    dedicated to the x86 System Management Mode (SMM).  It is expected that only
    a CPU in SMM can access the SMRAM. The CPU set a dedicated pin (SMIACT) when
    it is in SMM, for the Memory Controller to know. *)

(** * Specifying the Subsystem *)

(** The overview of the system we want to moder is the following:

<<
             |
             |
             v
      -----------------
     +-----------------+
     |Memory Controller|
     +-----------------+
       |            |
       |            |
       v            v
 ----------     ----------
+----------+   +----------+
|   DRAM   |   |   VGA    |
|Controller|   |Controller|
+----------+   +----------+
>>
    We will focus on the Memory Controller, and only model the interfaces of the
    DRAM and VGA controllers. *)

(** ** Addressing Memories *)

(** We leave how the memory is actually addressed (in terms of memory cell
    addresses and contents) as a parameter of the model. *)

Parameters (address cell : Type)
           (address_eq : address -> address -> Prop)
           (address_eq_refl : forall (addr addr' : address),
               address_eq addr addr' -> address_eq addr' addr)
           (address_eq_dec : forall (addr addr' : address),
               { address_eq addr addr' } + { ~ address_eq addr addr' })
           (in_smram : address -> bool)
           (in_smram_morphism : forall (addr addr' : address),
               address_eq addr addr' -> in_smram addr = in_smram addr').

(** ** VGA and DRAM Controllers *)

(** We consider that the DRAM and VGA controllers expose the same interface
    which allows for reading from and writing to memory cells. *)

Inductive MEMORY : interface :=
| ReadFrom (addr : address) : MEMORY cell
| WriteTo (addr : address) (value : cell) : MEMORY unit.

Inductive DRAM : interface :=
| MakeDRAM {a : Type} (e : MEMORY a) : DRAM a.

Definition dram_read_from `{Provide ix DRAM} (addr : address)
  : impure ix cell :=
  request (MakeDRAM (ReadFrom addr)).

Definition dram_write_to `{Provide ix DRAM} (addr : address) (val : cell)
  : impure ix unit :=
  request (MakeDRAM (WriteTo addr val)).

Inductive VGA : interface :=
| MakeVGA {a : Type} (e : MEMORY a) : VGA a.

Definition vga_read_from `{Provide ix VGA} (addr : address) : impure ix cell :=
  request (MakeVGA (ReadFrom addr)).

Definition vga_write_to `{Provide ix VGA} (addr : address) (val : cell)
  : impure ix unit :=
  request (MakeVGA (WriteTo addr val)).

(** ** Memory Controller *)

Inductive smiact := smiact_set | smiact_unset.

Inductive MEMORY_CONTROLLER : interface :=
| Read (pin : smiact) (addr : address) : MEMORY_CONTROLLER cell
| Write (pin : smiact) (addr : address) (value : cell) : MEMORY_CONTROLLER unit.

Definition unwrap_sumbool {A B} (x : { A } + { B }) : bool :=
  if x then true else false.

Coercion unwrap_sumbool : sumbool >-> bool.

Definition dispatch {a} `{Provide3 ix (STORE bool) DRAM VGA}
    (addr : address) (unpriv : address -> impure ix a) (priv : address -> impure ix a)
  : impure ix a :=
  do var reg <- get in
     if (andb reg (in_smram addr))
     then unpriv addr
     else priv addr
  end.

Definition memory_controller `{Provide3 ix (STORE bool) DRAM VGA}
  : component MEMORY_CONTROLLER ix :=
  fun _ op =>
    match op with

(** When SMIACT is set, the CPU is in SMM.  According to its specification, the
    Memory Controller can simply forward the memory access to the DRAM *)

    | Read smiact_set addr => dram_read_from addr
    | Write smiact_set addr val => dram_write_to addr val

(** On the contrary, when the SMIACT is not set, the CPU is not in SMM.  As a
    consequence, the memory controller implements a dedicated access control
    mechanism.  If the requested address belongs to the SMRAM and if the SMRAM
    lock has been set, then the memory access is forwarded to the VGA.
    Otherwise, it is forwarded to the DRAM by default.  This is specified in the
    [dispatch] function. *)

    | Read smiact_unset addr => dispatch addr vga_read_from dram_read_from
    | Write smiact_unset addr val =>
      dispatch addr (fun x => vga_write_to x val) (fun x => dram_write_to x val)
    end.

(** * Verifying our Subsystem *)

(** ** Memory View *)

Definition memory_view : Type := address -> cell.

Definition update_memory_view_address (ω : memory_view) (addr : address) (content : cell)
  : memory_view :=
  fun (addr' : address) => if address_eq_dec addr addr' then content else ω addr'.

(** ** Specification *)

(** *** DRAM Controller Specification *)

Definition update_dram_view (ω : memory_view) (a : Type) (p : DRAM a) (_ : a) : memory_view :=
  match p with
  | MakeDRAM (WriteTo a v)  => update_memory_view_address ω a v
  | _ => ω
  end.

Inductive dram_promises (ω : memory_view) : forall (a : Type), DRAM a -> a -> Prop :=

| read_in_smram
    (a : address) (v : cell) (prom : in_smram a = true -> v = ω a)
  : dram_promises ω cell (MakeDRAM (ReadFrom a)) (ω a)

| write (a : address) (v : cell) (r : unit)
  : dram_promises ω unit (MakeDRAM (WriteTo a v)) r.

Definition dram_specs : specs DRAM memory_view :=
  {| witness_update := update_dram_view
   ; requirements := no_req
   ; promises := dram_promises
   |}.

(** *** Memory Controller Specification *)

Definition update_memory_controller_view (ω : memory_view)
    (a : Type) (p : MEMORY_CONTROLLER a) (_ : a)
  : memory_view :=
  match p with
  | Write smiact_set a v  => update_memory_view_address ω a v
  | _ => ω
  end.

Inductive memory_controller_promises (ω : memory_view)
  : forall (a : Type) (p : MEMORY_CONTROLLER a) (x : a), Prop :=

| memory_controller_read_promises (pin : smiact) (addr : address) (content : cell)
    (prom : pin = smiact_set -> in_smram addr = true -> ω addr = content)
  : memory_controller_promises ω cell (Read pin addr) content

| memory_controller_write_promises (pin : smiact) (addr : address) (content : cell) (b : unit)
  : memory_controller_promises ω unit (Write pin addr content) b.

Definition mc_specs : specs MEMORY_CONTROLLER memory_view :=
  {| witness_update := update_memory_controller_view
   ; requirements := no_req
   ; promises := memory_controller_promises
   |}.

(** ** Main Theorem *)

Definition smram_pred (ωmc : memory_view) (ωmem : memory_view * bool) : Prop :=
  snd ωmem = true /\ forall (a : address), in_smram a = true -> ωmc a = (fst ωmem) a.

Lemma memory_controller_trustworthy `{StrictProvide3 ix (STORE bool) VGA DRAM}
    (a : Type) (op : MEMORY_CONTROLLER a) (ω : memory_view)
  : trustworthy_impure (dram_specs ⊙ store_specs bool) (ω, true) (memory_controller a op).

Proof.
  destruct op; destruct pin;
    prove_impure.
Qed.

#[local]
Open Scope semantics_scope.
#[local]
Open Scope specs_scope.

Theorem memory_controller_correct `{StrictProvide3 ix VGA (STORE bool) DRAM}
    (ω : memory_view)
    (sem : semantics ix) (comp : compliant_semantics (dram_specs <.> store_specs bool) (ω, true) sem)
  : compliant_semantics mc_specs ω (derive_semantics memory_controller sem).

Proof.
  apply correct_component_derives_compliant_semantics with (pred := smram_pred)
                                                           (specj := dram_specs <.> store_specs bool)
                                                           (ωj := (ω, true)).
  + intros ωmc [ωdram b] [b_true pred] a e req; cbn in *.
    split.
    ++ rewrite b_true.
       apply memory_controller_trustworthy.
    ++ intros x [ωdram' st'] trustworthy.
       destruct e.
       +++ split; [| now unroll_impure_run trustworthy ].
           destruct pin.
           ++++ unroll_impure_run trustworthy;
                  constructor;
                  intros pin_equ is_in_smram;
                  rewrite pred; auto;
                    now inversion H8; ssubst.
           ++++ now constructor.
       +++ split.
           ++++ now constructor.
           ++++ unroll_impure_run trustworthy;
                  (split; [ auto |]);
                  intros addr' is_in_smram';
                  unfold update_memory_view_address;
                  cbn;
                  rewrite pred; auto;
                    destruct address_eq_dec; auto.
                inversion H13; ssubst.
                cbn in equ.
                rewrite (in_smram_morphism _ _ a) in equ.
                now rewrite equ in is_in_smram'.
  + split; auto.
  + auto.
Qed.
