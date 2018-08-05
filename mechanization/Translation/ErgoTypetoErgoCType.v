(*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *)

(* Support for ErgoType models *)

Require Import String.
Require Import List.

Require Import ErgoSpec.Backend.ErgoBackend.
Require Import ErgoSpec.Common.Utils.ENames.
Require Import ErgoSpec.Common.Utils.EUtil.
Require Import ErgoSpec.Common.Utils.EResult.
Require Import ErgoSpec.Common.Utils.EProvenance.
Require Import ErgoSpec.Common.Utils.EAstUtil.
Require Import ErgoSpec.Common.Types.ErgoType.

Section ErgoTypeExpansion.
  Definition expand_hierarchy : Set := list string.
  Definition expanded_type : Set := list (string * laergo_type).
  Definition expand_ctxt : Set := list (string * (expand_hierarchy * expanded_type)).

  (** Assumes decls sorted in topological order *)
  Definition ergo_expand_extends
             (ctxt:expand_ctxt)
             (this:absolute_name)
             (super:absolute_name)
             (localtype:list (string * laergo_type)) : expand_ctxt :=
    match lookup string_dec ctxt super with
    | None => ctxt (** XXX Should be a system error *)
    | Some (hierarchy, etype) =>
      (this, (super::hierarchy,etype ++ localtype)) :: ctxt
    end.

  Definition ergo_decl_expand_extends (ctxt:expand_ctxt)
             (this:absolute_name)
             (decl_desc:laergo_type_declaration_desc) : expand_ctxt :=
    match decl_desc with
    | ErgoTypeEnum _ => ctxt
    | ErgoTypeTransaction None rtl =>
      if string_dec this "org.hyperledger.composer.system.Transaction"%string
      then (this, (nil, rtl)) :: ctxt
      else ergo_expand_extends ctxt this "org.hyperledger.composer.system.Transaction"%string rtl
    | ErgoTypeTransaction (Some super) rtl =>
      ergo_expand_extends ctxt this super rtl
    | ErgoTypeConcept None rtl =>
      (this, (nil, rtl)) :: ctxt
    | ErgoTypeConcept (Some super) rtl =>
      ergo_expand_extends ctxt this super rtl
    | ErgoTypeEvent None rtl =>
      if string_dec this "org.hyperledger.composer.system.Event"%string
      then (this, (nil, rtl)) :: ctxt
      else ergo_expand_extends ctxt this "org.hyperledger.composer.system.Event"%string rtl
    | ErgoTypeEvent (Some super) rtl =>
      ergo_expand_extends ctxt this super rtl
    | ErgoTypeAsset None rtl =>
      if string_dec this "org.hyperledger.composer.system.Asset"%string
      then (this, (nil, rtl)) :: ctxt
      else ergo_expand_extends ctxt this "org.hyperledger.composer.system.Asset"%string rtl
    | ErgoTypeAsset (Some super) rtl =>
      ergo_expand_extends ctxt this super rtl
    | ErgoTypeParticipant None rtl =>
      if string_dec this "org.hyperledger.composer.system.Participant"%string
      then (this, (nil, rtl)) :: ctxt
      else ergo_expand_extends ctxt this "org.hyperledger.composer.system.Participant"%string rtl
    | ErgoTypeParticipant (Some super) rtl =>
      ergo_expand_extends ctxt this super rtl
    | ErgoTypeGlobal _ => ctxt
    | ErgoTypeFunction _ => ctxt
    | ErgoTypeContract _ _ _ => ctxt
    end.

  Fixpoint ergo_expand_extends_in_declarations (decls:list laergo_type_declaration) : expand_ctxt :=
    List.fold_left
      (fun ctxt decl =>
         ergo_decl_expand_extends
           ctxt
           decl.(type_declaration_name)
           decl.(type_declaration_type))
      decls nil.

  Definition ergo_hierarchy_from_expand (ctxt : expand_ctxt) :=
    List.concat
      (List.map (fun xyz =>
                   List.map (fun x => (fst xyz, x)) (fst (snd xyz)))
                ctxt).

End ErgoTypeExpansion.

Section ErgoTypetoErgoCType.
  Context {m:brand_relation}.
  Import ErgoCTypes.

  Fixpoint ergo_type_to_ergoc_type (t:laergo_type) : ergoc_type :=
    match t with
    | ErgoTypeAny _ => ttop
    | ErgoTypeNone _ => tbottom
    | ErgoTypeBoolean _ => tbool
    | ErgoTypeString _ => tstring
    | ErgoTypeDouble _ => tfloat
    | ErgoTypeLong _ => tfloat
    | ErgoTypeInteger _ => tnat
    | ErgoTypeDateTime _ => tstring (*XXX TO FIX! *)
    | ErgoTypeClassRef _ cr => tbrand (cr::nil)
    | ErgoTypeOption _ t => teither (ergo_type_to_ergoc_type t) tunit
    | ErgoTypeRecord _ rtl =>
      trec
        open_kind
        (rec_sort (List.map (fun xy => (fst xy, ergo_type_to_ergoc_type (snd xy))) rtl))
        (rec_sort_sorted
           (List.map (fun xy => (fst xy, ergo_type_to_ergoc_type (snd xy))) rtl)
           (rec_sort (List.map (fun xy => (fst xy, ergo_type_to_ergoc_type (snd xy))) rtl))
           eq_refl)
    | ErgoTypeArray _ t => tcoll (ergo_type_to_ergoc_type t)
    | ErgoTypeSum _ t1 t2 => teither (ergo_type_to_ergoc_type t1) (ergo_type_to_ergoc_type t2)
    end.

  Definition ergo_ctype_decl_from_expand (ctxt : expand_ctxt) : tbrand_context_decls :=
    List.map (fun xyz =>
                (fst xyz,
                 let rtl := snd (snd xyz) in
                 trec
                   open_kind
                   (rec_sort (List.map (fun xy => (fst xy, ergo_type_to_ergoc_type (snd xy))) rtl))
                   (rec_sort_sorted
                      (List.map (fun xy => (fst xy, ergo_type_to_ergoc_type (snd xy))) rtl)
                      (rec_sort (List.map (fun xy => (fst xy, ergo_type_to_ergoc_type (snd xy))) rtl))
                      eq_refl))) ctxt.

End ErgoTypetoErgoCType.

Section Translate.
  Local Open Scope string.
  Import ErgoCTypes.

  Definition brand_relation_maybe hierarchy : eresult tbrand_relation
    := eresult_of_qresult dummy_provenance (mk_tbrand_relation hierarchy).

  (* Compute (brand_relation_maybe StoreDecls). *)

  Definition mk_model_type_decls {br:brand_relation} (ctxt : expand_ctxt) : tbrand_context_decls :=
    @ergo_ctype_decl_from_expand br ctxt.

  Definition label_of_decl (decl:laergo_type_declaration) : string :=
    decl.(type_declaration_name).
  Definition name_of_decl : laergo_type_declaration -> string := label_of_decl.
  Definition decls_table (decls:list laergo_type_declaration) : list (string * laergo_type_declaration) :=
    List.map (fun d => (d.(type_declaration_name), d)) decls.
  Definition edge_of_decl (dt:list (string * laergo_type_declaration)) (decl:laergo_type_declaration) : laergo_type_declaration * list laergo_type_declaration :=
    let outedges := type_declaration_extend_rel decl in
    (decl, List.concat (List.map (fun xy => match lookup string_dec dt (snd xy) with | None => nil | Some x => x :: nil end) outedges)).
  Definition graph_of_decls (decls:list laergo_type_declaration)
    : list (laergo_type_declaration * list (laergo_type_declaration)) :=
    let dt := decls_table decls in
    map (edge_of_decl dt) decls.
    
  Definition sort_decls (decls:list laergo_type_declaration) : list laergo_type_declaration :=
    coq_toposort label_of_decl name_of_decl (graph_of_decls decls).

  Definition brand_model_of_declarations (decls:list laergo_type_declaration)
    : eresult ErgoCTypes.tbrand_model :=
    let decls := sort_decls decls in
    let ctxt := ergo_expand_extends_in_declarations decls in
    let hierarchy := ergo_hierarchy_from_expand ctxt in
    eolift (fun br =>
              eresult_of_qresult dummy_provenance
                                 (mk_tbrand_model (@mk_model_type_decls br ctxt)))
           (brand_relation_maybe hierarchy).
  
  Definition force_brand_model_of_declarations (decls:list laergo_type_declaration)
    : ErgoCTypes.tbrand_model :=
    match brand_model_of_declarations decls with
    | Success _ _ s => s
    | Failure _ _ e => tempty_brand_model (* Not used *)
    end.

  (* Compute brand_model_of_declarations StoreDecls. *)

End Translate.

