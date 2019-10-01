From Coq Require Import ssreflect ssrfun ssrbool.
From Coq Require FunctionalExtensionality.
From Mon Require Export Base.
From Mon.SRelation Require Import SRelation_Definitions SMorphisms.
From Mon.sprop Require Import SPropBase SPropMonadicStructures MonadExamples SpecificationMonads.
From Relational Require Import Category RelativeMonads (* RelativeMonadExamples *) Rel.

Set Universe Polymorphism.

Definition M1 := Exn unit.
Definition M2 := Identity.
Definition W1 := ExnSpec unit.
Definition W2 := MonoContSProp.

Definition Wrel A1 A2 := MonoContSProp (option A1 × A2).

Import SPropNotations.

Program Definition retWrel {A1 A2} a1 a2 : Wrel A1 A2 :=
  ⦑fun p => p ⟨Some a1, a2⟩⦒.
Next Obligation. cbv ; intuition. Qed.

Program Definition bindWrel
        {A1 A2 B1 B2}
        (wm1 : W1 A1) (wm2 : W2 A2) (wmrel : Wrel A1 A2)
        (wf1 : A1 -> W1 B1) (wf2 : A2 -> W2 B2) (wfrel : A1 × A2 -> Wrel B1 B2)
  : Wrel B1 B2
  :=
    ⦑fun p => wmrel∙1 (fun a12 => match nfst a12 with
                          | Some a1 => (wfrel ⟨a1, nsnd a12⟩)∙1 p
                          | None => (wf2 (nsnd a12))∙1 (fun b2 => p ⟨None, b2⟩)
                               end)⦒.
Next Obligation.
  cbv; move=> p1 p2 Hp; apply wmrel∙2=> [[[?|] ?]];
    [apply: (wfrel _)∙2| apply: (wf2 _)∙2]; move=> ? ; apply: Hp.
Qed.

Import RelNotations.

Definition extends (Γ : Rel) (A1 A2 : Type) : Rel :=
  mkRel (πl Γ × A1) (πr Γ × A2) (fun γa1 γa2 => Γ (nfst γa1) (nfst γa2)).

Definition extendsLow (Γ : Rel) (A : Type) : Rel :=
  mkRel (πl Γ × A) (πr Γ × A) (fun γa1 γa2 =>
                                 Γ (nfst γa1) (nfst γa2) × (nsnd γa1 = nsnd γa2)).

Check (fun Γ (γ : ⟬Γ⟭) => πl γ) .

Definition extend_point {Γ A1 A2} (γ : ⟬Γ⟭) (a1:A1) (a2:A2) : ⟬extends Γ A1 A2⟭.
Proof. exists ⟨⟨πl γ, a1⟩, ⟨πr γ, a2⟩⟩. exact: πw γ. Defined.

Program Definition bindWrelStrong
        {Γ A1 A2 B1 B2}
        (wm1 : πl Γ -> W1 A1) (wm2 : πr Γ -> W2 A2) (wmrel : ⟬Γ⟭ -> Wrel A1 A2)
        (wf1 : πl Γ × A1 -> W1 B1) (wf2 : πr Γ × A2 -> W2 B2)
        (wfrel : ⟬extends Γ A1 A2⟭ -> Wrel B1 B2)
  : ⟬Γ⟭ -> Wrel B1 B2
  :=
    fun γ =>
      ⦑fun p =>
         let k a12 :=
             match nfst a12 with
             | Some a1 => (wfrel (extend_point γ a1 (nsnd a12)))∙1 p
             | None => (wf2 ⟨πr γ, nsnd a12⟩)∙1 (fun b2 => p ⟨None, b2⟩)
             end
         in (wmrel γ)∙1 k⦒.
Next Obligation.
  cbv; move=> p1 p2 Hp; apply: (wmrel _)∙2=> [[[?|] ?]];
    [apply: (wfrel _)∙2| apply: (wf2 _)∙2]; move=> ? ; apply: Hp.
Qed.

Section StrongBind.
  Context {M:Monad}.
  Context {Γ A B} (m : Γ -> M A) (f : Γ × A -> M B).

  Definition bindStr (γ : Γ) : M B :=
    bind (m γ) (fun a => f ⟨γ,a⟩).
End StrongBind.


Notation "x ⩿ y" := (pointwise_srelation _ (@omon_rel _ _) x y) (at level 70).

Program Definition raise_spec : W1 False :=
  ⦑fun p pexc => pexc tt⦒.
Next Obligation. cbv ; intuition. Qed.

Program Definition rel_raise_spec {A2} (a2:A2) : Wrel False A2 :=
  ⦑fun p => p ⟨None, a2⟩⦒.
Next Obligation. cbv ; intuition. Qed.


Definition catchStr {Γ E A} (m : Γ -> Exn E A) (merr : Γ × E -> Exn E A)
  : Γ -> Exn E A := fun γ => catch (m γ) (fun e => merr ⟨γ,e⟩).

Program Definition catch_spec {A1} (w:W1 A1) (werr : unit -> W1 A1) : W1 A1 :=
  ⦑fun p pexc => w∙1 p (fun u => (werr u)∙1 p pexc)⦒.
Next Obligation.
  cbv ; intuition.
  move: H1; apply: w∙2=> // ?; apply (werr _)∙2 => //.
Qed.


Program Definition catch_spec_str {Γ A1} (w:Γ -> W1 A1) (werr : Γ × unit -> W1 A1)
  : Γ -> W1 A1 :=
  fun γ => ⦑fun p pexc => (w γ)∙1 p (fun u => (werr ⟨γ,u⟩)∙1 p pexc)⦒.
Next Obligation.
  cbv ; intuition.
  move: H1; apply: (w _)∙2=> // ?; apply (werr _)∙2 => //.
Qed.

Program Definition rel_catch_spec {A1 A2} (wmrel : Wrel A1 A2)
           (wmerr : unit -> W1 A1) (* (wmerr_rel : unit -> Wrel A1 A2) *)
  : Wrel A1 A2 :=
  ⦑fun p => wmrel∙1 (fun ae12 => match nfst ae12 with
                           | Some a1 => p ⟨Some a1, nsnd ae12⟩
                           | None => (wmerr tt)∙1 (fun a1 => p ⟨Some a1, nsnd ae12⟩)
                                              (fun u => p ⟨None, nsnd ae12⟩)
                           end)⦒.

Next Obligation.
  cbv. move=> p1 p2 Hp ; apply: (wmrel)∙2=> [[[?|] ?]] ; first by apply: Hp.
  apply: (wmerr _)∙2=> ?; apply: Hp.
Qed.


Program Definition rel_catch_spec_str
        {Γ A1 A2} (wmrel : ⟬Γ⟭ -> Wrel A1 A2)
           (wmerr : πl Γ × unit -> W1 A1) (* (wmerr_rel : unit -> Wrel A1 A2) *)
  : ⟬Γ⟭ -> Wrel A1 A2 :=
  fun γ =>
    ⦑fun p => (wmrel γ)∙1 (fun ae12 => match nfst ae12 with
                             | Some a1 => p ⟨Some a1, nsnd ae12⟩
                             | None => (wmerr ⟨πl γ, tt⟩)∙1 (fun a1 => p ⟨Some a1, nsnd ae12⟩)
                                                (fun u => p ⟨None, nsnd ae12⟩)
                             end)⦒.

Next Obligation.
  cbv. move=> p1 p2 Hp ; apply: (wmrel _)∙2=> [[[?|] ?]] ; first by apply: Hp.
  apply: (wmerr _)∙2=> ?; apply: Hp.
Qed.

Definition extend_bool_eq
           {Γ A} (b: Γ -> bool)
           (m_true : { γ:Γ ⫳ b γ = true } -> A)
           (m_false: { γ:Γ ⫳ b γ = false } -> A)
           (γ : Γ) : A :=
  (if b γ as b0 return b γ = b0 -> A
   then fun H => m_true (dpair _ γ H)
   else fun H => m_false (dpair _ γ H)) eq_refl.

Definition dep_extend (Γ : Rel) (b : Γ R==> TyRel) : Rel :=
  mkRel {γl : πl Γ ⫳ πl b γl}
        {γr : πr Γ ⫳ πr b γr}
        (fun γbl γbr =>
           { γw : Γ (dfst γbl) (dfst γbr)
           ⫳ πw b (dfst γbl) (dfst γbr) γw (dsnd γbl) (dsnd γbr)  } ).

Definition mk_point (R : Rel) (xl : πl R) (xr : πr R) (xw : R xl xr) : ⟬R⟭ :=
  dpair _ ⟨xl, xr⟩ xw.

Definition rel_is_bool (b0 : bool) {Γ} (b : Γ R==> Lo bool) : Γ R==> TyRel :=
  mk_point (Γ R=> TyRel) (fun γl => πl b γl = b0) (fun γr => πr b γr = b0)
           (fun γl γr γw b_eql b_eqr => unit).

Let rel_is_true {Γ} := @rel_is_bool true Γ.
Let rel_is_false {Γ} := @rel_is_bool false Γ.

Definition rel_extend_bool_eq
           {Γ A} (b: Γ R==> Lo bool)
           (m_true : ⟬dep_extend Γ (rel_is_true b)⟭ -> A)
           (m_false: ⟬dep_extend Γ (rel_is_false b)⟭ -> A)
           (γ : ⟬Γ⟭) : A :=
  let bs := b @R γ in
  (if πr bs as b0 return πr bs = b0 -> A
   then fun H => m_true
                (mk_point (dep_extend Γ (rel_is_true b))
                          (dpair _ (πl γ) (eq_trans (πw bs) H))
                          (dpair _ (πr γ) H)
                          (dpair _ (πw γ) tt))
                (* (dpair _ γ (mk_point (rel_is_true b @R γ) (eq_trans (πw bs) H) H tt)) *)
   else fun H => m_false
                (mk_point (dep_extend Γ (rel_is_false b))
                          (dpair _ (πl γ) (eq_trans (πw bs) H))
                          (dpair _ (πr γ) H)
                          (dpair _ (πw γ) tt))
                (* (dpair _ γ (mk_point (rel_is_false b @R γ) (eq_trans (πw bs)) H) H tt) *)
  ) eq_refl.

Definition subst_nil {Γ A} : Γ -> Γ × list A := fun γ => ⟨γ, nil⟩.
Definition rel_subst_nil {Γ A} : ⟬Γ⟭ -> ⟬Γ ,∙ list A⟭ :=
  fun γ => mk_point (Γ ,∙ list A) (subst_nil (πl γ)) (subst_nil (πr γ))
                 ⟨πw γ, eq_refl⟩.
Definition subst_cons {Γ A} : Γ × A × list A -> Γ × list A :=
  fun γal => ⟨nfst (nfst γal), cons (nsnd (nfst γal)) (nsnd γal)⟩.
Program Definition rel_subst_cons {Γ A} : ⟬Γ,∙A,∙list A⟭ -> ⟬Γ ,∙ list A⟭ :=
  fun γ => mk_point (Γ ,∙ list A) (subst_cons (πl γ)) (subst_cons (πr γ))
                 ⟨nfst (nfst (πw γ)), eq_refl⟩.
Next Obligation. move: γ=> [? [[?]]] /= -> -> //. Qed.


Inductive valid :
  forall (Γ : Rel) A1 A2,
    (πl Γ -> M1 A1) -> (πl Γ -> W1 A1) ->
    (πr Γ -> M2 A2) -> (πr Γ -> W2 A2) ->
    (⟬Γ⟭ -> Wrel A1 A2) -> Type :=

| ValidRet : forall Γ A1 A2 a1 a2,
    valid Γ A1 A2  (ret \o a1)  (ret \o a1) (ret \o a2) (ret \o a2) (fun γ => retWrel (a1 (πl γ)) (a2 (πr γ)))

| ValidBind :
    forall Γ A1 A2 B1 B2 m1 wm1 m2 wm2 wmrel f1 wf1 f2 wf2 wfrel,
    valid Γ A1 A2 m1 wm1 m2 wm2 wmrel ->
    valid (extends Γ A1 A2) B1 B2 f1 wf1 f2 wf2 wfrel ->
    valid Γ B1 B2
          (bindStr m1 f1) (bindStr wm1 wf1)
          (bindStr m2 f2) (bindStr wm2 wf2)
          (bindWrelStrong wm1 wm2 wmrel wf1 wf2 wfrel)
| ValidWeaken :
    forall Γ A1 A2 m1 wm1 wm1' m2 wm2 wm2' wmrel wmrel',
      valid Γ A1 A2 m1 wm1 m2 wm2 wmrel ->
      wm1 ⩿ wm1' -> wm2 ⩿ wm2' -> wmrel ⩿ wmrel' ->
      valid Γ A1 A2 m1 wm1' m2 wm2' wmrel'

| ValidRaise :
    forall Γ A2 a2,
      valid Γ False A2 (fun=> raise tt) (fun=> raise_spec) (fun=> ret a2) (fun=> ret a2)
            (fun=> rel_raise_spec a2)
| ValidCatch :
    forall Γ A1 A2 m1 wm1 m2 wm2 wmrel merr wmerr wmerr_rel,
      valid Γ A1 A2 m1 wm1 m2 wm2 wmrel ->
      valid (extends Γ unit A2) A1 A2 merr wmerr (fun γa2 => ret (nsnd γa2)) (fun γa2 => ret (nsnd γa2)) wmerr_rel ->
      valid Γ A1 A2
            (catchStr m1 merr) (catch_spec_str wm1 wmerr)
            m2 wm2
            (rel_catch_spec_str wmrel wmerr)

| ValidBoolElim :
    forall Γ (b : Γ R==> Lo bool) A1 A2
      m1_true wm1_true m2_true wm2_true wmrel_true
      m1_false wm1_false m2_false wm2_false wmrel_false ,
    valid (dep_extend Γ (rel_is_true b)) A1 A2 m1_true wm1_true m2_true wm2_true wmrel_true ->
    valid (dep_extend Γ (rel_is_false b)) A1 A2 m1_false wm1_false m2_false wm2_false wmrel_false ->
    valid Γ A1 A2
          (extend_bool_eq (πl b) m1_true m1_false)
          (extend_bool_eq (πl b) wm1_true wm1_false)
          (extend_bool_eq (πr b) m2_true m2_false)
          (extend_bool_eq (πr b) wm2_true wm2_false)
          (rel_extend_bool_eq b wmrel_true wmrel_false).
(* | ValidListElim : *)
(*     forall Γ A A1 A2 m1 wm1 m2 wm2 wmrel, *)
(*       valid Γ A1 A2 *)
(*             (m1 \o subst_nil) (wm1 \o subst_nil) *)
(*             (m2 \o subst_nil) (wm2 \o subst_nil) *)
(*             (wmrel \o rel_subst_nil) -> *)
(*       (valid (Γ,∙ list A) A1 A2 m1 wm1 m2 wm2 wmrel -> *)
(*        valid (Γ,∙ A ,∙ list A) A1 A2 *)
(*              (m1 \o subst_cons) (wm1 \o subst_cons) *)
(*              (m2 \o subst_cons) (wm2 \o subst_cons) *)
(*              (wmrel \o rel_subst_cons)) -> *)
(*       valid (Γ,∙ list A) A1 A2 m1 wm1 m2 wm2 wmrel. *)


From Coq Require Import Lists.List.

Notation "m1 ;; m2" := (bind m1 (fun=> m2)) (at level 65).

Definition prog1 {A} (l : list A) (pred : A -> bool) : M1 bool :=
  let fix aux (l : list A) : M1 unit :=
      match l with
      | nil => ret tt
      | x :: l => if pred x then (raise tt ;; ret tt) else aux l
      end
  in catch (aux l ;; ret false) (fun => ret true).

Definition prog2 {A} (l : list A) (pred : A -> bool) : M2 bool :=
  let fix aux (l : list A) : M2 bool :=
      match l with
      | nil => ret false
      | x :: l => if pred x then ret true else aux l
      end
  in aux l.

Definition prog1' {A} (lp : list A × (A -> bool)) :=
  prog1 (nfst lp) (nsnd lp).

Definition prog2' {A} (lp : list A × (A -> bool)) :=
  prog2 (nfst lp) (nsnd lp).

Program Definition prog1_spec : MonoContSProp (option bool) :=
  ⦑ fun p => forall b, p (some b) ⦒.
Next Obligation.
  cbv; intuition.
Qed.

Program Definition prog2_spec : MonoContSProp bool :=
  ⦑ fun p => forall b, p b ⦒.
Next Obligation.
  cbv; intuition.
Qed.

Program Definition prog1_prog2_spec : Wrel bool bool :=
  ⦑ fun p => forall b, p ⟨some b, b⟩ ⦒.
Next Obligation.
  cbv; intuition.
Qed.

Lemma prog1_prog2_equiv {A} : valid ((EmptyCtx ,∘ (list A)) ,∘ (A -> bool))
                                    bool bool prog1' prog1_spec prog2' prog2_spec
                                    prog1_prog2_spec.