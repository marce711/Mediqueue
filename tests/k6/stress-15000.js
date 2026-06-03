import runIteration, { handleSummary, makeOptions } from './mediqueue-scenario.js';

export const options = makeOptions(15000, 300, 'stress-15000');

export default runIteration;
export { handleSummary };
