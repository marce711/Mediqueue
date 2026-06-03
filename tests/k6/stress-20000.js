import runIteration, { handleSummary, makeOptions } from './mediqueue-scenario.js';

export const options = makeOptions(20000, 400, 'stress-20000');

export default runIteration;
export { handleSummary };
