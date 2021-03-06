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
Require Import Qcert.Utils.Closure.
Require Import Qcert.Common.CommonSystem.
Require Import Qcert.Compiler.Model.CompilerRuntime.
Require Import Qcert.Translation.NNRCtoJavaScript.
Require Import Qcert.cNNRC.Lang.cNNRC.

Require Import ErgoSpec.Backend.Model.DateTimeModelPart.
Require Import ErgoSpec.Backend.Model.ErgoEnhancedModel.
Require Import ErgoSpec.Backend.ForeignErgo.
Require Import ErgoSpec.Backend.Model.ErgoBackendModel.

Module ErgoBackendRuntime <: ErgoBackendModel.
  Local Open Scope string.

  Definition ergo_foreign_data := enhanced_foreign_data.
  Definition ergo_data_to_json_string := NNRCtoJavaScript.dataToJS.
  Definition ergo_foreign_type := enhanced_foreign_type.

End ErgoBackendRuntime.
