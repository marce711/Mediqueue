import runIteration, { handleSummary, makeOptions } from './mediqueue-scenario.js';

export const options = makeOptions(5000, 100, 'stress-5000');

export default runIteration;
export { handleSummary };
