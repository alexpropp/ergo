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

(** Translates CTO to Ergo Types *)

Require Import String.
Require Import List.
Require Import Qcert.Utils.Utils.

Require Import ErgoSpec.Backend.ErgoBackend.
Require Import ErgoSpec.Common.Utils.ENames.
Require Import ErgoSpec.Common.Utils.EResult.
Require Import ErgoSpec.Common.Utils.EImport.
Require Import ErgoSpec.Common.CTO.CTO.
Require Import ErgoSpec.Common.Types.ErgoType.

Section CTOtoErgoType.

  Fixpoint cto_type_to_ergo_type (ct:cto_type) : ergo_type :=
    match ct with
    | CTOBoolean => ErgoTypeBoolean
    | CTOString => ErgoTypeString
    | CTODouble => ErgoTypeDouble
    | CTOLong => ErgoTypeLong
    | CTOInteger => ErgoTypeInteger
    | CTODateTime => ErgoTypeDateTime
    | CTOClassRef n => ErgoTypeClassRef n
    | CTOOption ct1 => ErgoTypeOption (cto_type_to_ergo_type ct1)
    | CTOArray ct1 => ErgoTypeArray (cto_type_to_ergo_type ct1)
    end.

  Definition cto_declaration_kind_to_ergo_type_declaration_kind (dk:cto_declaration_kind) :=
    match dk with
    | CTOEnum ls => ErgoTypeEnum ls
    | CTOTransaction on crec =>
      ErgoTypeTransaction on (map (fun xy => (fst xy, cto_type_to_ergo_type (snd xy))) crec)
    | CTOConcept on crec =>
      ErgoTypeConcept on (map (fun xy => (fst xy, cto_type_to_ergo_type (snd xy))) crec)
    | CTOEvent on crec =>
      ErgoTypeEvent on (map (fun xy => (fst xy, cto_type_to_ergo_type (snd xy))) crec)
    | CTOAsset on crec =>
      ErgoTypeAsset on (map (fun xy => (fst xy, cto_type_to_ergo_type (snd xy))) crec)
    | CTOParticipant on crec =>
      ErgoTypeParticipant on (map (fun xy => (fst xy, cto_type_to_ergo_type (snd xy))) crec)
    end.  

  Definition cto_declaration_to_ergo_type_declaration (d:cto_declaration) : ergo_type_declaration :=
    mkErgoTypeDeclaration
      d.(cto_declaration_name)
      (cto_declaration_kind_to_ergo_type_declaration_kind d.(cto_declaration_type)).

  Definition cto_package_to_ergo_type_package (p:cto_package) : ergo_type_package :=
    mkErgoTypePackage
      p.(cto_package_namespace)
      p.(cto_package_imports)
      (map cto_declaration_to_ergo_type_declaration p.(cto_package_declarations)).

End CTOtoErgoType.