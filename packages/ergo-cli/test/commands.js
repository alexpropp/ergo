/*
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
 */

'use strict';

const Commands = require('../lib/commands');
const Chai = require('chai');

Chai.should();
Chai.use(require('chai-things'));
const Path = require('path');

describe('ergo', () => {

    afterEach(() => {});

    describe('#executehello', function () {
        it('should execute a smart Ergo contract', async function () {
            const ergoPath = Path.resolve(__dirname, 'data/helloworld', 'logic.ergo');
            const ctoPath = Path.resolve(__dirname, 'data/helloworld', 'model.cto');
            const contractPath = Path.resolve(__dirname, 'data/helloworld', 'contract.json');
            const requestPath = Path.resolve(__dirname, 'data/helloworld', 'request.json');
            const statePath = Path.resolve(__dirname, 'data/helloworld', 'state.json');
            const result = await Commands.execute([ergoPath], [ctoPath], contractPath, [requestPath], statePath, 'org.accordproject.helloworld.HelloWorld', false);
            result.response.output.should.equal('Hello Fred Blogs (Accord Project)');
        });
        it('should throw when executing a smart Ergo contract without its cto', async function () {
            const ergoPath = Path.resolve(__dirname, 'data/helloworld', 'logic.ergo');
            const contractPath = Path.resolve(__dirname, 'data/helloworld', 'contract.json');
            const requestPath = Path.resolve(__dirname, 'data/helloworld', 'request.json');
            const statePath = Path.resolve(__dirname, 'data/helloworld', 'state.json');
            const result = await Commands.execute([ergoPath], undefined, contractPath, [requestPath], statePath, 'org.accordproject.helloworld.HelloWorld', false);
            result.error.kind.should.equal('CompilationError');
            result.error.message.should.equal('Cannot find type with name \'TemplateModel\'');
            result.error.locstart.should.deep.equal({ 'line' : 16, 'character' : 25 });
            result.error.locend.should.deep.equal({ 'line' : 16, 'character' : 38 });
        });
    });
    describe('#executemissing', function () {
        it('should fail when executing missing Ergo', async function () {
            const ctoPath = Path.resolve(__dirname, 'data/helloworld', 'model.cto');
            const contractPath = Path.resolve(__dirname, 'data/helloworld', 'contract.json');
            const requestPath = Path.resolve(__dirname, 'data/helloworld', 'request.json');
            const statePath = Path.resolve(__dirname, 'data/helloworld', 'state.json');
            const result = await Commands.execute(undefined, [ctoPath], contractPath, [requestPath], statePath, 'org.accordproject.helloworld.HelloWorld', false);
            result.error.message.should.equal('No input ergo found');
        });
    });
    describe('#executehellostate', function () {
        it('should execute a smart Ergo contract with state once', async function () {
            const ergoPath = Path.resolve(__dirname, 'data/helloworldstate', 'logic.ergo');
            const ctoPath = Path.resolve(__dirname, 'data/helloworldstate', 'model.cto');
            const contractPath = Path.resolve(__dirname, 'data/helloworldstate', 'contract.json');
            const requestPath = Path.resolve(__dirname, 'data/helloworldstate', 'request.json');
            const statePath = Path.resolve(__dirname, 'data/helloworldstate', 'state.json');
            const result = await Commands.execute([ergoPath], [ctoPath], contractPath, [requestPath], statePath, 'org.accordproject.helloworldstate.HelloWorldState', false);
            result.response.output.should.equal('Hello Fred Blogs (Accord Project) (1.0)');
        });
        it('should execute a smart Ergo contract with state thrice', async function () {
            const ergoPath = Path.resolve(__dirname, 'data/helloworldstate', 'logic.ergo');
            const ctoPath = Path.resolve(__dirname, 'data/helloworldstate', 'model.cto');
            const contractPath = Path.resolve(__dirname, 'data/helloworldstate', 'contract.json');
            const requestPath = Path.resolve(__dirname, 'data/helloworldstate', 'request.json');
            const statePath = Path.resolve(__dirname, 'data/helloworldstate', 'state.json');
            const result = await Commands.execute([ergoPath], [ctoPath], contractPath, [requestPath,requestPath,requestPath], statePath, 'org.accordproject.helloworldstate.HelloWorldState', false);
            result.response.output.should.equal('Hello Fred Blogs (Accord Project) (3.0)');
        });
    });
    describe('#executeinstallmentsale', function () {
        it('should initialize a smart Ergo contract state', async function () {
            const ergoPath = Path.resolve(__dirname, 'data/installment-sale', 'logic.ergo');
            const ctoPath = Path.resolve(__dirname, 'data/installment-sale', 'model.cto');
            const contractPath = Path.resolve(__dirname, 'data/installment-sale', 'contract.json');
            const requestInitPath = Path.resolve(__dirname, 'data/installment-sale', 'request-init.json');
            const result = await Commands.execute([ergoPath], [ctoPath], contractPath, [requestInitPath], null, 'org.accordproject.installmentsale.InstallmentSale', false);
            result.state.balance_remaining.should.equal(10000.00);
        });
        it('should initialize a smart Ergo contract and execute one request', async function () {
            const ergoPath = Path.resolve(__dirname, 'data/installment-sale', 'logic.ergo');
            const ctoPath = Path.resolve(__dirname, 'data/installment-sale', 'model.cto');
            const contractPath = Path.resolve(__dirname, 'data/installment-sale', 'contract.json');
            const requestInitPath = Path.resolve(__dirname, 'data/installment-sale', 'request-init.json');
            const requestPath = Path.resolve(__dirname, 'data/installment-sale', 'request.json');
            const result = await Commands.execute([ergoPath], [ctoPath], contractPath, [requestInitPath,requestPath], null, 'org.accordproject.installmentsale.InstallmentSale', false);
            result.state.balance_remaining.should.equal(7612.499999999999);
        });
    });
    describe('#executepromissorynote', function () {
        it('should execute a smart Ergo contract', async function () {
            const ergoPath = Path.resolve(__dirname, 'data/promissory-note', 'logic.ergo');
            const ctoPath1 = Path.resolve(__dirname, 'data/promissory-note', 'business.cto');
            const ctoPath2 = Path.resolve(__dirname, 'data/promissory-note', 'model.cto');
            const contractPath = Path.resolve(__dirname, 'data/promissory-note', 'contract.json');
            const requestPath = Path.resolve(__dirname, 'data/promissory-note', 'request.json');
            const statePath = Path.resolve(__dirname, 'data/promissory-note', 'state.json');
            const result = await Commands.execute([ergoPath], [ctoPath1, ctoPath2], contractPath, [requestPath], statePath, 'org.accordproject.promissorynote.PromissoryNote', false);
            result.response.outstandingBalance.should.equal(1425.4396822450633);
        });
    });
    describe('#executepromissorynotemodule', function () {
        it('should execute a smart Ergo contract with two modules', async function () {
            const ergoPath1 = Path.resolve(__dirname, 'data/promissory-note', 'money.ergo');
            const ergoPath2 = Path.resolve(__dirname, 'data/promissory-note', 'logic3.ergo');
            const ctoPath1 = Path.resolve(__dirname, 'data/promissory-note', 'business.cto');
            const ctoPath2 = Path.resolve(__dirname, 'data/promissory-note', 'model.cto');
            const contractPath = Path.resolve(__dirname, 'data/promissory-note', 'contract.json');
            const requestPath = Path.resolve(__dirname, 'data/promissory-note', 'request.json');
            const statePath = Path.resolve(__dirname, 'data/promissory-note', 'state.json');
            const result = await Commands.execute([ergoPath1, ergoPath2], [ctoPath1, ctoPath2], contractPath, [requestPath], statePath, 'org.accordproject.promissorynote.PromissoryNote', false);
            result.response.outstandingBalance.should.equal(1425.4396822450633);
        });
    });
    describe('#parsectotofile', function () {
        it('should parse CTO to CTOJ', async function () {
            const ctoPath = Path.resolve(__dirname, 'data/helloworld', 'model.cto');
            const result = await Commands.parseCTOtoFile(ctoPath);
            result.should.not.be.null;
        });
    });
});
