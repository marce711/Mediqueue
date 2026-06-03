import runIteration, { handleSummary, makeOptions } from './mediqueue-scenario.js';

export const options = makeOptions(10000, 200, 'stress-10000');

export default runIteration;
export { handleSummary };
