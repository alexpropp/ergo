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

Require Import String.
Require Import List.
Require Import Basics.

Require Import ErgoSpec.Backend.ErgoBackend.
Require Import ErgoSpec.Common.Utils.Misc.
Require Import ErgoSpec.Common.Utils.Names.
Require Import ErgoSpec.Common.Utils.NamespaceContext.
Require Import ErgoSpec.Common.Utils.Result.
Require Import ErgoSpec.Common.Utils.Provenance.
Require Import ErgoSpec.Common.Utils.Ast.
Require Import ErgoSpec.Common.Utils.PrintTypedData.
Require Import ErgoSpec.Common.Types.ErgoTypetoErgoCType.
Require Import ErgoSpec.ErgoC.Lang.ErgoC.
Require Import ErgoSpec.ErgoC.Lang.ErgoCTypeContext.
Require Import ErgoSpec.Ergo.Lang.Ergo.

Section ErgoCType.
  Context {m : brand_model}.

  Import ErgoCTypes.

  Definition ergoc_type_join_safe prov (t1 t2:ergoc_type) : eresult ergoc_type :=
    let jt := ergoc_type_join t1 t2 in
    if ergoc_type_subtype_dec ttop jt
    then efailure (ETypeError prov ("Join between types is TOP.")%string)
    else esuccess jt.

  Definition ergoc_type_meet_safe prov (t1 t2:ergoc_type) : eresult ergoc_type :=
    let jt := ergoc_type_meet t1 t2 in
    if ergoc_type_subtype_dec jt tbottom
    then efailure (ETypeError prov ("Meet between types is BOTTOM.")%string)
    else esuccess jt.

  Program Definition empty_rec_type : ergoc_type := Rec Closed nil _.

  Definition ergo_format_unop_error nsctxt (op : unary_op) (arg : ergoc_type) : string :=
    let fmt_easy :=
        fun name expected actual =>
          ("Operator `" ++ name ++ "' expected an operand of type `" ++
                        (ergoc_type_to_string nsctxt expected) ++
                        "' but received an operand of type `" ++
                        (ergoc_type_to_string nsctxt actual) ++ "'.")%string
    in
    match op with
    | OpNeg => fmt_easy "!"%string tbool arg
    | OpFloatUnary FloatNeg => fmt_easy "-"%string tfloat arg
    | OpDot name => "The field " ++ name ++ " does not belong to type `" ++ (ergoc_type_to_string nsctxt arg) ++ "'"
    | _ => "This operator received an unexpected argument of type `" ++ (ergoc_type_to_string nsctxt arg) ++ "'"
    end.

  Definition ergo_format_binop_error nsctxt (op : binary_op) (arg1 : ergoc_type) (arg2 : ergoc_type) : string :=
    let fmt_easy :=
        fun name e1 e2 =>
          ("Operator `" ++ name ++ "' expected operands of type `" ++
                        (ergoc_type_to_string nsctxt e1) ++ "' and `" ++
                        (ergoc_type_to_string nsctxt e2) ++
                        "' but received operands of type `" ++
                        (ergoc_type_to_string nsctxt arg1) ++ "' and `" ++
                        (ergoc_type_to_string nsctxt arg2) ++ "'.")%string
    in
    match op with
    | OpAnd => fmt_easy "and"%string tbool tbool
    | OpOr => fmt_easy "or"%string tbool tbool
    | OpFloatBinary FloatPlus => fmt_easy "+"%string tfloat tfloat
    | OpFloatBinary FloatMinus => fmt_easy "-"%string tfloat tfloat
    | OpFloatBinary FloatMult => fmt_easy "*"%string tfloat tfloat
    | OpFloatBinary FloatDiv => fmt_easy "/"%string tfloat tfloat
    | OpFloatBinary FloatPow => fmt_easy "^"%string tfloat tfloat
    | OpNatBinary NatPlus => fmt_easy "+i"%string tnat tnat
    | OpNatBinary NatMinus => fmt_easy "-i"%string tnat tnat
    | OpNatBinary NatMult => fmt_easy "*i"%string tnat tnat
    | OpNatBinary NatDiv => fmt_easy "/i"%string tnat tnat
    | OpNatBinary NatPow => fmt_easy "^i"%string tnat tnat
    | OpFloatCompare FloatLt => fmt_easy "<"%string tfloat tfloat
    | OpFloatCompare FloatLe => fmt_easy "<="%string tfloat tfloat
    | OpFloatCompare FloatGt => fmt_easy ">"%string tfloat tfloat
    | OpFloatCompare FloatGe => fmt_easy ">="%string tfloat tfloat
    | _ => "This operator received unexpected arguments of type `" ++ (ergoc_type_to_string nsctxt arg1) ++ "' " ++ " and `" ++ (ergoc_type_to_string nsctxt arg2) ++ "'."
    end.

  Definition ergo_format_new_error nsctxt (name:string) (actual:ergoc_type) : string :=
    let concept_name := ergoc_type_to_string nsctxt (Brand (name::nil)) in
    (* First check if all the fields are present and no extra field is present *)
    match diff_record_types (name::nil) actual with
    | None => "Concept name " ++ name ++ " does not match data"
    | Some (nil, nil) =>
      (* If all the fields are right, check if any of them is not a subtype *)
      match fields_that_are_not_subtype (name::nil) actual with
      | nil => "Concept " ++ name ++ " doesn't match data (one field is not a subtype)"
      | (expected_name, expected_type, actual_type) :: _ =>
        "Field `" ++ expected_name
                  ++ "' has type `" ++ (ergoc_type_to_string nsctxt actual_type)
                  ++ "' but should have type `" ++ (ergoc_type_to_string nsctxt expected_type) ++ "'"
      end
    | Some (nil, actual_name::nil) =>
      "Unknown field `" ++ actual_name ++ "' in type `" ++ concept_name ++ "'"
    | Some (nil, actual_names) =>
      "Unknown fields `" ++ String.concat "', `" actual_names ++ "' in type `" ++ concept_name ++ "'"
    | Some (expected_name::nil, _) =>
      "Missing field `" ++ expected_name ++ "' in type `" ++ concept_name ++ "'"
    | Some (expected_names, _) =>
      "Missing fields `" ++ String.concat "', `" expected_names ++ "' in type `" ++ concept_name ++ "'"
    end.

  Definition ergo_format_clause_return_fallback_error
             nsctxt
             (name:string)
             (actual expected:ergoc_type) : string :=
    let actual_s := ergoc_type_to_string nsctxt actual in
    let expected_s := ergoc_type_to_string nsctxt expected in
    "Clause " ++ name ++ " should return `" ++ expected_s
              ++ "' but actually returns `" ++ actual_s ++ "'".

  Definition ergo_format_clause_return_component_error
             nsctxt
             (name:string)
             (component1 component2:string)
             (actual expected:ergoc_type) : string :=
    let actual_s := ergoc_type_to_string nsctxt actual in
    let expected_s := ergoc_type_to_string nsctxt expected in
    "Clause " ++ name ++ " should " ++ component1 ++ " `" ++ expected_s
              ++ "' but actually " ++ component2 ++ " `" ++ actual_s ++ "'".

  Definition ergo_format_clause_return_normal_error
             nsctxt
             (name:string)
             (actual expected:ergoc_type)
             (actual_quad expected_quad:ergoc_type * ergoc_type * ergoc_type * ergoc_type)
    : string :=
    let '(actual_resp, actual_emit, actual_state, actual_error) := actual_quad in
    let '(expected_resp, expected_emit, expected_state, expected_error) := expected_quad in
    if ergoc_type_subtype_dec actual_resp expected_resp
    then
      if ergoc_type_subtype_dec actual_emit expected_emit
      then
        if ergoc_type_subtype_dec actual_state expected_state
        then
          if ergoc_type_subtype_dec actual_error expected_error
          then
            ergo_format_clause_return_fallback_error nsctxt name actual expected
          else
            ergo_format_clause_return_component_error
              nsctxt name "fail with" "fails with" actual_error expected_error
        else
          ergo_format_clause_return_component_error
            nsctxt name "set state" "sets state" actual_state expected_state
      else
        ergo_format_clause_return_component_error
          nsctxt name "emit" "emits" actual_emit expected_emit
    else
      ergo_format_clause_return_component_error
        nsctxt name "respond" "responds" actual_resp expected_resp.

  Definition ergo_format_clause_return_error nsctxt (name:string) (actual expected:ergoc_type) : string :=
    let actual_quad := unpack_output_type nsctxt actual in
    let expected_quad := unpack_output_type nsctxt expected in
    let normal_error := ergo_format_clause_return_normal_error nsctxt name actual expected in
    let fallback_error := fun e => ergo_format_clause_return_fallback_error nsctxt name actual expected in
    elift2_both
      normal_error
      fallback_error
      actual_quad
      expected_quad.
  
  Definition ergo_format_function_return_error nsctxt (name:string) (actual expected:ergoc_type) : string :=
    let actual_s := ergoc_type_to_string nsctxt actual in
    let expected_s := ergoc_type_to_string nsctxt expected in
    "Function " ++ name ++ " should return `" ++ expected_s ++ "' but actually returns `" ++ actual_s ++ "'".
  
  Fixpoint ergo_type_expr nsctxt (ctxt : type_context) (expr : ergoc_expr) : eresult ergoc_type :=
    match expr with
    | EThisContract prov => efailure (ESystemError prov "No `this' in ergoc")
    | EThisClause   prov => efailure (ESystemError prov "No `clause' in ergoc")
    | EThisState    prov => efailure (ESystemError prov "No `state' in ergoc")
    | EVar prov name =>
      let opt := lookup String.string_dec (ctxt.(type_context_local_env)++ctxt.(type_context_global_env)) name in
      eresult_of_option opt (ETypeError prov ("Variable `" ++ name ++ "' not found.")%string)
    | EConst prov d =>
      eresult_of_option
        (infer_data_type d)
        (ETypeError prov "Bad constant.")
    | ENone prov => esuccess (toption tbottom)
    | ESome prov e => elift toption (ergo_type_expr nsctxt ctxt e)
    | EArray prov es =>
      (elift tcoll)
        (fold_left
           (fun T new =>
              eolift
                (fun T' =>
                   elift
                     (fun new' => ergoc_type_join T' new')
                     (ergo_type_expr nsctxt ctxt new))
                T)
           es (esuccess tbottom))
    | EUnaryOp prov op e =>
      match ergo_type_expr nsctxt ctxt e with
      | Success _ _ t =>
        match ergoc_type_infer_unary_op op t with
        | Some (r, _) => esuccess r
        | None => efailure (ETypeError prov (ergo_format_unop_error nsctxt op t))
        end
      | Failure _ _ f => efailure f
      end
    | EBinaryOp prov op e1 e2 =>
      match ergo_type_expr nsctxt ctxt e1 with
      | Success _ _ t1 =>
        match ergo_type_expr nsctxt ctxt e2 with
        | Success _ _ t2 =>
          match ergoc_type_infer_binary_op op t1 t2 with
          | Some (r, _, _) => esuccess r
          | None => efailure (ETypeError prov (ergo_format_binop_error nsctxt op t1 t2))
          end
        | Failure _ _ f => efailure f
        end
      | Failure _ _ f => efailure f
      end
    | EIf prov c t f =>
      eolift (fun c' =>
                if ergoc_type_subtype_dec c' tbool then
                  elift2 ergoc_type_join
                         (ergo_type_expr nsctxt ctxt t)
                         (ergo_type_expr nsctxt ctxt f)
                else efailure (ETypeError (expr_annot c) "'if' condition not boolean."%string))
             (ergo_type_expr nsctxt ctxt c)
    | ELet prov n None v e =>
      (eolift (fun vt =>
                let ctxt' := type_context_update_local_env ctxt n vt in
                ergo_type_expr nsctxt ctxt' e)
             (ergo_type_expr nsctxt ctxt v))
    | ELet prov n (Some t) v e  =>
      let fmt_err :=
          fun t' vt =>
          match prov with
          | ProvFunc _ fname =>
            ETypeError prov
                       ("Function `" ++ fname
                                     ++ "' expected argument `"
                                     ++ n
                                     ++ "' to be of type `"
                                     ++ (ergoc_type_to_string nsctxt t')
                                     ++ "' but was given argument of type `"
                                     ++ (ergoc_type_to_string nsctxt vt)
                                     ++ "'." )
          | _ => ETypeError prov
                            ("The let type annotation `"
                               ++ (ergoc_type_to_string nsctxt t')
                               ++ "' for the name `"
                               ++ n
                               ++ "' does not match the actual type `"
                               ++ (ergoc_type_to_string nsctxt vt)
                               ++ "'.")
          end
      in
      (eolift
         (fun vt =>
            let t' := (ergo_type_to_ergoc_type t) in
            if subtype_dec vt t' then
              let ctxt' :=
                  type_context_update_local_env
                    ctxt n
                    t'
              in
              ergo_type_expr nsctxt ctxt' e
            else
              efailure (fmt_err t' vt))
         (ergo_type_expr nsctxt ctxt v))
    | ERecord prov rs =>
      fold_left
        (fun sofar next =>
           eolift2
             (fun sofar' val' =>
                (elift (compose fst fst))
                  (eresult_of_option
                     (ergoc_type_infer_binary_op OpRecConcat sofar' val')
                     (ETypeError prov "Bad record! Failed to concat."%string)))
             sofar
             (eolift (fun val =>
                        (elift fst)
                          (eresult_of_option
                             (ergoc_type_infer_unary_op (OpRec (fst next)) val)
                             (ETypeError prov "Bad record! Failed to init."%string)))
                     (ergo_type_expr nsctxt ctxt (snd next))))
        rs (esuccess empty_rec_type)
    | ENew prov name rs =>
      eolift
        (fun rs' =>
           (elift fst)
             (eresult_of_option
                (infer_brand_strict (name::nil) rs')
                (ETypeError prov (ergo_format_new_error nsctxt name rs'))))
        (fold_left
           (fun sofar next =>
              eolift2
                (fun sofar' val' =>
                   (elift (compose fst fst))
                     (eresult_of_option
                        (ergoc_type_infer_binary_op OpRecConcat sofar' val')
                        (ETypeError prov "Bad record! Failed to concat."%string)))
                sofar
                (eolift (fun val =>
                           (elift fst)
                             (eresult_of_option
                                (ergoc_type_infer_unary_op (OpRec (fst next)) val)
                                (ETypeError prov "Bad record! Failed to init."%string)))
                        (ergo_type_expr nsctxt ctxt (snd next))))
           rs (esuccess empty_rec_type))
    | ECallFun prov fname args => function_not_inlined_error prov fname
    | ECallFunInGroup prov gname fname args => function_in_group_not_inlined_error prov gname fname
    | EMatch prov term pes default =>
      match ergo_type_expr nsctxt ctxt term with
      | Failure _ _ f => efailure f
      | Success _ _ t0 =>
        fold_left
          (fun default_result pe =>
             match pe with
             | (CaseData prov d, res) => (* TODO can `d' ever be bad? *)
               match ergoc_type_infer_data d with
               | None => efailure (ETypeError prov "Ill-typed data literal!")
               | Some dt =>
                 elift2 ergoc_type_join
                        default_result
                        (ergo_type_expr nsctxt ctxt res)
               end
             | (CaseWildcard prov None, res) =>
               elift2 ergoc_type_join default_result (ergo_type_expr nsctxt ctxt res)
             | (CaseLet prov name None, res) =>
               elift2 ergoc_type_join default_result
                      (ergo_type_expr nsctxt (type_context_update_local_env ctxt name t0) res)
             | (CaseLetOption prov name None, res) =>
               match unteither t0 with
               | None => default_result
               | Some (st, ft) =>
                 elift2 ergoc_type_join default_result
                        (ergo_type_expr nsctxt (type_context_update_local_env ctxt name st) res)
               end
             | (CaseWildcard prov (Some b), res) =>
               elift2 ergoc_type_join default_result
                      (ergo_type_expr nsctxt ctxt res)

             | (CaseLet prov name (Some b), res) =>
               elift2 ergoc_type_join default_result
                      (ergo_type_expr nsctxt (type_context_update_local_env
                                         ctxt
                                         name
                                         (tbrand (b::nil)))
                                      res)
             | (CaseLetOption prov name (Some b), res) =>
               elift2 ergoc_type_join default_result
                      (ergo_type_expr nsctxt (type_context_update_local_env
                                         ctxt
                                         name
                                         (tbrand (b::nil)))
                                      res)
             end)
          pes (ergo_type_expr nsctxt ctxt default)
      end
    (* EXPECTS: each foreach has only one dimension and no where *)
    | EForeach prov ((name,arr)::nil) None fn =>
      eolift (fun arr' =>
                eolift
                  (fun typ => (elift tcoll) (ergo_type_expr nsctxt (type_context_update_local_env ctxt name typ) fn))
                (eresult_of_option
                  (untcoll arr')
                  (ETypeError
                     prov
                     ("foreach expects an array to iterate over, but was given something of type `" ++ (ergoc_type_to_string nsctxt arr') ++ "'."))))
            (ergo_type_expr nsctxt ctxt arr)
            
    | EForeach prov _ _ _ =>
      complex_foreach_in_calculus_error prov
    end.

  Definition ergoc_type_function
             (nsctxt: namespace_ctxt)
             (name:string)
             (dctxt : type_context)
             (func : ergoc_function) : eresult type_context :=
    match func.(functionc_body) with
    | None => esuccess dctxt
    | Some body =>
      let tsig :=
          map (fun x => (fst x, ergo_type_to_ergoc_type (snd x)))
              func.(functionc_sig).(sigc_params) in
      eolift
        (fun outt =>
           let eoutt := func.(functionc_sig).(sigc_output) in
           match eoutt with
           | None => esuccess dctxt
           | Some eoutt' =>
             let expectedt := ergo_type_to_ergoc_type eoutt' in
             if subtype_dec
                  outt
                  expectedt
             then esuccess dctxt
             else
               let body_prov := bodyc_annot func in
               match func.(functionc_annot) with
               | ProvClause _ name =>
                 efailure (ETypeError body_prov (ergo_format_clause_return_error nsctxt name outt expectedt))
               | ProvFunc _ name =>
                 efailure (ETypeError body_prov (ergo_format_function_return_error nsctxt name outt expectedt))
               | _ =>
                 efailure (ETypeError body_prov (ergo_format_function_return_error nsctxt name outt expectedt))
               end
           end)
        (ergo_type_expr nsctxt (type_context_set_local_env dctxt tsig) body)
    end.

  Definition ergoc_type_clause
             (nsctxt: namespace_ctxt)
             (dctxt : type_context)
             (cl : string * ergoc_function) : eresult type_context :=
    let (name,body) := cl in
    ergoc_type_function nsctxt name dctxt body.

  Definition ergoc_type_contract
             (nsctxt: namespace_ctxt)
             (dctxt : type_context)
             (coname: absolute_name)
             (c : ergoc_contract) : eresult type_context :=
    elift_fold_left
      (ergoc_type_clause nsctxt)
      c.(contractc_clauses)
      dctxt.

  Definition ergoc_type_decl
             (nsctxt: namespace_ctxt)
             (dctxt : type_context)
             (decl : ergoc_declaration)
    : eresult (option ergoc_type * type_context) :=
    match decl with
    | DCExpr prov expr =>
      elift (fun x => (Some x, dctxt)) (ergo_type_expr nsctxt dctxt expr)
    | DCConstant prov name None expr =>
      let expr' := ergo_type_expr nsctxt dctxt expr in
      eolift (fun val => esuccess (None, type_context_update_global_env dctxt name val)) expr'
    | DCConstant prov name (Some t) expr =>
      let fmt_err :=
          fun t' vt =>
            ETypeError prov
                       ("The type annotation `"
                          ++ (ergoc_type_to_string nsctxt t')
                          ++ "' for the constant `"
                          ++ name
                          ++ "' does not match its actual type `"
                          ++ (ergoc_type_to_string nsctxt vt)
                          ++ "'.")
      in
      let expr' := ergo_type_expr nsctxt dctxt expr in
      eolift (fun vt =>
                let t' := (ergo_type_to_ergoc_type t) in
                if subtype_dec vt t' then
                  let ctxt' :=
                      type_context_update_global_env dctxt name t'
                  in
                  esuccess (None, ctxt')
            else
              efailure (fmt_err t' vt)) expr'
    | DCFunc prov name func =>
      elift (fun ctxt => (None,ctxt)) (ergoc_type_function nsctxt name dctxt func)
    | DCContract prov name contr =>
      elift (fun ctxt => (None,ctxt)) (ergoc_type_contract nsctxt dctxt name contr)
    end.

  Definition ergoc_type_module
             (nsctxt: namespace_ctxt)
             (dctxt : type_context)
             (mod : ergoc_module)
    : eresult (ergoc_module * type_context) :=
    elift (fun x => (mod, snd x))
          (elift_context_fold_left
             (ergoc_type_decl nsctxt)
             mod.(modulec_declarations)
             dctxt).
  
End ErgoCType.
