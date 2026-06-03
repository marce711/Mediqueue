import http from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';
import { Counter, Rate } from 'k6/metrics';

const DEFAULT_BASE_URL = 'http://localhost:8080';
const BASE_URL = (__ENV.BASE_URL || DEFAULT_BASE_URL).replace(/\/+$/, '');
const RUN_ID = __ENV.RUN_ID || String(Date.now()).slice(-8);
const THINK_TIME_SECONDS = parseFloat(__ENV.THINK_TIME_SECONDS || '0');
const ENDPOINT_SET = (__ENV.ENDPOINT_SET || 'all').toLowerCase();
const DEFAULT_WRITE_RATIO = ENDPOINT_SET === 'all' ? '0.05' : '0';
const WRITE_RATIO = parseFloat(__ENV.WRITE_RATIO || DEFAULT_WRITE_RATIO);
const REQUEST_TIMEOUT = __ENV.REQUEST_TIMEOUT || '';

const endpointCounters = {
  readPacientes: new Counter('mediqueue_read_pacientes_total'),
  readDoctores: new Counter('mediqueue_read_doctores_total'),
  readEspecialidades: new Counter('mediqueue_read_especialidades_total'),
  readHorarios: new Counter('mediqueue_read_horarios_total'),
  readAppointments: new Counter('mediqueue_read_appointments_total'),
  readPayments: new Counter('mediqueue_read_payments_total'),
  readNotificaciones: new Counter('mediqueue_read_notificaciones_total'),
  createPacientes: new Counter('mediqueue_create_pacientes_total'),
};

const successfulResponses = new Rate('mediqueue_successful_responses');

const readEndpoints = [
  { key: 'readPacientes', service: 'paciente', method: 'GET', path: '/api/pacientes', name: 'GET /api/pacientes' },
  { key: 'readDoctores', service: 'doctor', method: 'GET', path: '/api/horarios/doctores', name: 'GET /api/horarios/doctores' },
  { key: 'readEspecialidades', service: 'doctor', method: 'GET', path: '/api/horarios/especialidades', name: 'GET /api/horarios/especialidades' },
  { key: 'readHorarios', service: 'doctor', method: 'GET', path: '/api/horarios', name: 'GET /api/horarios' },
  { key: 'readAppointments', service: 'cita', method: 'GET', path: '/api/v1/appointments', name: 'GET /api/v1/appointments' },
  { key: 'readPayments', service: 'pago', method: 'GET', path: '/api/payments', name: 'GET /api/payments' },
  { key: 'readNotificaciones', service: 'notificacion', method: 'GET', path: '/api/notificaciones', name: 'GET /api/notificaciones' },
];

const activeReadEndpoints = filterReadEndpoints();

export function makeOptions(totalRequests, defaultVus, profileName) {
  const requests = integerEnv('TARGET_REQUESTS', totalRequests);
  const vus = integerEnv('VUS', defaultVus);
  const thresholds = {
    http_req_failed: [__ENV.HTTP_REQ_FAILED_THRESHOLD || 'rate<0.10'],
    mediqueue_successful_responses: [__ENV.SUCCESS_RATE_THRESHOLD || 'rate>0.90'],
  };

  if ((__ENV.DISABLE_LATENCY_THRESHOLDS || '').toLowerCase() !== 'true') {
    thresholds.http_req_duration = [
      `p(95)<${integerEnv('P95_THRESHOLD_MS', 3000)}`,
      `p(99)<${integerEnv('P99_THRESHOLD_MS', 6000)}`,
    ];
  }

  return {
    scenarios: {
      mediqueue_stress: {
        executor: 'shared-iterations',
        vus,
        iterations: requests,
        maxDuration: __ENV.MAX_DURATION || '20m',
      },
    },
    thresholds,
    summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
    tags: {
      app: 'mediqueue',
      profile: __ENV.PROFILE || profileName,
      testid: __ENV.TEST_ID || `${profileName}-${RUN_ID}`,
    },
    userAgent: 'mediqueue-k6-stress/1.0',
    noConnectionReuse: false,
  };
}

export default function runIteration() {
  const endpoint = Math.random() < WRITE_RATIO ? createPacienteEndpoint() : pickReadEndpoint();
  const response = execute(endpoint);
  const ok = endpoint.method === 'POST'
    ? response.status === 201
    : response.status >= 200 && response.status < 300;

  endpointCounters[endpoint.key].add(1);
  successfulResponses.add(ok);

  check(response, {
    [`${endpoint.name} status valido`]: () => ok,
    [`${endpoint.name} responde antes de 3s`]: (res) => res.timings.duration < 3000,
  });

  if (THINK_TIME_SECONDS > 0) {
    sleep(THINK_TIME_SECONDS);
  }
}

export function handleSummary(data) {
  const profile = (__ENV.PROFILE || data.root_group.name || 'mediqueue').replace(/[^a-zA-Z0-9_.-]/g, '_');
  const fileName = `tests/k6/results/summary-${profile}-${RUN_ID}.json`;

  return {
    stdout: buildTextSummary(data),
    [fileName]: JSON.stringify(data, null, 2),
  };
}

function execute(endpoint) {
  const params = {
    headers: endpoint.headers || {},
    tags: {
      endpoint: endpoint.name,
      target_service: endpoint.service || 'paciente',
      type: endpoint.method === 'POST' ? 'write' : 'read',
    },
  };

  if (REQUEST_TIMEOUT) {
    params.timeout = REQUEST_TIMEOUT;
  }

  if (endpoint.method === 'POST') {
    params.headers['Content-Type'] = 'application/json';
    return http.post(`${BASE_URL}${endpoint.path}`, JSON.stringify(endpoint.body), params);
  }

  return http.get(`${BASE_URL}${endpoint.path}`, params);
}

function pickReadEndpoint() {
  return activeReadEndpoints[Math.floor(Math.random() * activeReadEndpoints.length)];
}

function createPacienteEndpoint() {
  const iteration = exec.scenario.iterationInTest;
  const dpi = `9${RUN_ID}${String(iteration).padStart(8, '0')}`;

  return {
    key: 'createPacientes',
    method: 'POST',
    path: '/api/pacientes',
    name: 'POST /api/pacientes',
    body: {
      dpi,
      correo: `stress-${RUN_ID}-${iteration}@mediqueue.test`,
      nombre: `Paciente Stress ${RUN_ID}-${iteration}`,
      telefono: `55${String(iteration).slice(-6).padStart(6, '0')}`,
    },
  };
}

function filterReadEndpoints() {
  switch (ENDPOINT_SET) {
    case 'doctor-only':
      return readEndpoints.filter((endpoint) => endpoint.service === 'doctor');
    case 'no-doctor':
      return readEndpoints.filter((endpoint) => endpoint.service !== 'doctor');
    case 'paciente-only':
      return readEndpoints.filter((endpoint) => endpoint.service === 'paciente');
    case 'cita-only':
      return readEndpoints.filter((endpoint) => endpoint.service === 'cita');
    case 'pago-only':
      return readEndpoints.filter((endpoint) => endpoint.service === 'pago');
    case 'notificacion-only':
      return readEndpoints.filter((endpoint) => endpoint.service === 'notificacion');
    default:
      return readEndpoints;
  }
}

function integerEnv(name, fallback) {
  const value = Number.parseInt(__ENV[name] || '', 10);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

function buildTextSummary(data) {
  const metrics = data.metrics;
  const duration = metrics.http_req_duration?.values || {};
  const failed = metrics.http_req_failed?.values || {};
  const reqs = metrics.http_reqs?.values || {};

  return [
    '',
    'Mediqueue k6 summary',
    `Requests: ${reqs.count ?? 'n/a'}`,
    `Failures: ${percentage(failed.rate)}`,
    `Duration avg: ${formatMs(duration.avg)}`,
    `Duration p95: ${formatMs(duration['p(95)'])}`,
    `Duration p99: ${formatMs(duration['p(99)'])}`,
    `Summary JSON written under tests/k6/results`,
    '',
  ].join('\n');
}

function percentage(value) {
  return typeof value === 'number' ? `${(value * 100).toFixed(2)}%` : 'n/a';
}

function formatMs(value) {
  return typeof value === 'number' ? `${value.toFixed(2)} ms` : 'n/a';
}
