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

const ErgoEngine = require('../lib/ergo-engine');
const Chai = require('chai');

Chai.should();
Chai.use(require('chai-things'));
Chai.use(require('chai-as-promised'));

const Fs = require('fs');
const Path = require('path');

// Set of tests
const workload = JSON.parse(Fs.readFileSync(Path.resolve(__dirname, 'workload.json'), 'utf8'));

/**
 * Compare actual result and expected result
 *
 * @param {string} expected the result as specified in the test workload
 * @param {string} actual the result as returned by the engine
 * @returns {object} Promise to the comparison
 */
function compare(expected,actual) {
    if (expected.hasOwnProperty('error')) {
        actual.error.should.not.be.null;
        return actual.error.should.deep.equal(expected.error);
    }
    if (expected.hasOwnProperty('state')) {
        // actual.state.should.not.be.null;
        for (const key in expected.state) {
            if (expected.state.hasOwnProperty(key)) {
                const field = key;
                const value = expected.state[key];
                actual.state[field].should.not.be.null;
                actual.state[field].should.deep.equal(value);
            }
        }
    }
    if (expected.hasOwnProperty('response')) {
        //console.info(JSON.stringify(actual.response));
        //actual.response.should.not.be.null;
        for (const key in expected.response) {
            if (expected.response.hasOwnProperty(key)) {
                const field = key;
                const value = expected.response[key];
                actual.response[field].should.not.be.null;
                actual.response[field].should.deep.equal(value);
            }
        }
    }
}

describe('Execute ES6', () => {

    afterEach(() => {});

    for (const i in workload) {
        const test = workload[i];
        const name = test.name;
        const dir = test.dir;
        const ergo = test.ergo;
        const models = test.models;
        const contract = test.contract;
        const request = test.request;
        const state = test.state;
        const contractname = test.contractname;
        const expected = test.expected;
        let resultKind;
        if (expected.hasOwnProperty('compilationerror') || expected.hasOwnProperty('error')) {
            resultKind = 'fail';
        } else {
            resultKind = 'succeed';
        }

        describe('#'+name, function () {
            it('should ' + resultKind + ' executing Ergo contract ' + contractname, async function () {
                const ergoSources = [];
                for (let i = 0; i < ergo.length; i++) {
                    const ergoFile = Path.resolve(__dirname, dir, ergo[i]);
                    const ergoContent = Fs.readFileSync(ergoFile, 'utf8');
                    ergoSources.push({ 'name': ergoFile, 'content': ergoContent });
                }
                let ctoSources = [];
                for (let i = 0; i < models.length; i++) {
                    const ctoFile = Path.resolve(__dirname, dir, models[i]);
                    const ctoContent = Fs.readFileSync(ctoFile, 'utf8');
                    ctoSources.push({ 'name': ctoFile, 'content': ctoContent });
                }
                const contractJson = JSON.parse(Fs.readFileSync(Path.resolve(__dirname, dir, contract), 'utf8'));
                const requestJson = JSON.parse(Fs.readFileSync(Path.resolve(__dirname, dir, request), 'utf8'));
                if (state === null) {
                    const actual = await ErgoEngine.init(ergoSources, ctoSources, 'es6', contractJson, requestJson, contractname);
                    return compare(expected,actual);
                } else {
                    const stateJson = JSON.parse(Fs.readFileSync(Path.resolve(__dirname, dir, state), 'utf8'));
                    const actual = await ErgoEngine.execute(ergoSources, ctoSources, 'es6', contractJson, requestJson, stateJson, contractname);
                    return compare(expected,actual);
                }
            });
        });
    }
});
describe('Execute ES5', () => {

    afterEach(() => {});

    for (const i in workload) {
        const test = workload[i];
        const name = test.name;
        const dir = test.dir;
        const ergo = test.ergo;
        const models = test.models;
        const contract = test.contract;
        const request = test.request;
        const state = test.state;
        const contractname = test.contractname;
        const expected = test.expected;
        let resultKind;
        if (expected.hasOwnProperty('compilationerror') || expected.hasOwnProperty('error')) {
            resultKind = 'fail';
        } else {
            resultKind = 'succeed';
        }

        describe('#'+name, function () {
            it('should ' + resultKind + ' executing Ergo contract ' + contractname, async function () {
                const ergoSources = [];
                for (let i = 0; i < ergo.length; i++) {
                    const ergoFile = Path.resolve(__dirname, dir, ergo[i]);
                    const ergoContent = Fs.readFileSync(ergoFile, 'utf8');
                    ergoSources.push({ 'name': ergoFile, 'content': ergoContent });
                }
                let ctoSources = [];
                for (let i = 0; i < models.length; i++) {
                    const ctoFile = Path.resolve(__dirname, dir, models[i]);
                    const ctoContent = Fs.readFileSync(ctoFile, 'utf8');
                    ctoSources.push({ 'name': ctoFile, 'content': ctoContent });
                }
                const contractJson = JSON.parse(Fs.readFileSync(Path.resolve(__dirname, dir, contract), 'utf8'));
                const requestJson = JSON.parse(Fs.readFileSync(Path.resolve(__dirname, dir, request), 'utf8'));
                if (state === null) {
                    const actual = await ErgoEngine.init(ergoSources, ctoSources, 'es5', contractJson, requestJson, contractname);
                    return compare(expected,actual);
                } else {
                    const stateJson = JSON.parse(Fs.readFileSync(Path.resolve(__dirname, dir, state), 'utf8'));
                    const actual = await ErgoEngine.execute(ergoSources, ctoSources, 'es5', contractJson, requestJson, stateJson, contractname);
                    return compare(expected,actual);
                }
            });
        });
    }
});
