package com.mediqueue.doctorhorario.service;

import com.mediqueue.doctorhorario.dto.DoctorHorarioResponse;
import com.mediqueue.doctorhorario.dto.DoctorRequest;
import com.mediqueue.doctorhorario.dto.DoctorResponse;
import com.mediqueue.doctorhorario.dto.DoctorScheduleRequest;
import com.mediqueue.doctorhorario.entity.Doctor;
import com.mediqueue.doctorhorario.entity.DoctorHorario;
import com.mediqueue.doctorhorario.exception.InvalidHorarioException;
import com.mediqueue.doctorhorario.entity.Specialty;
import com.mediqueue.doctorhorario.repository.DoctorHorarioRepository;
import com.mediqueue.doctorhorario.repository.DoctorRepository;
import com.mediqueue.doctorhorario.repository.SpecialtyRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

@Service
public class DoctorService {

    private final DoctorRepository doctorRepository;
    private final DoctorHorarioRepository horarioRepository;
    private final SpecialtyRepository specialtyRepository;

    public DoctorService(DoctorRepository doctorRepository, DoctorHorarioRepository horarioRepository, SpecialtyRepository specialtyRepository) {
        this.doctorRepository = doctorRepository;
        this.horarioRepository = horarioRepository;
        this.specialtyRepository = specialtyRepository;
    }

    @Transactional
    public DoctorResponse crear(DoctorRequest request) {
        String correo = normalize(request.correo()).toLowerCase();
        if (!correo.isBlank() && doctorRepository.existsByCorreo(correo)) {
            throw new InvalidHorarioException("Ya existe un doctor registrado con ese correo");
        }

        Specialty specialty = specialtyRepository.findById(request.specialtyId())
                .orElseThrow(() -> new InvalidHorarioException("Especialidad no encontrada con ID: " + request.specialtyId()));

        Doctor doctor = new Doctor();
        doctor.setNombre(normalize(request.nombre()));
        doctor.setSpecialty(specialty);
        doctor.setTelefono(blankToNull(request.telefono()));
        doctor.setCorreo(correo.isBlank() ? null : correo);
        doctor.setEstado(request.activo() == null || request.activo() ? "ACTIVO" : "INACTIVO");

        Doctor savedDoctor = doctorRepository.save(doctor);
        List<DoctorHorario> horarios = request.horarios().stream()
                .map(schedule -> buildHorario(savedDoctor.getId(), schedule))
                .map(horarioRepository::save)
                .toList();

        return toResponse(savedDoctor, horarios);
    }

    @Transactional(readOnly = true)
    public List<DoctorResponse> listar() {
        return doctorRepository.findByEstado("ACTIVO").stream()
                .map(doctor -> toResponse(
                        doctor,
                        horarioRepository.findByDoctorIdOrderByDiaSemanaAscHoraInicioAsc(doctor.getId())
                ))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Specialty> listarEspecialidades() {
        return specialtyRepository.findByActivaTrueOrderByNameAsc();
    }

    private DoctorHorario buildHorario(UUID doctorId, DoctorScheduleRequest schedule) {
        validarRangoHorario(schedule.horaInicio(), schedule.horaFin());
        DoctorHorario horario = new DoctorHorario();
        horario.setDoctorId(doctorId);
        horario.setDiaSemana(schedule.diaSemana());
        horario.setHoraInicio(schedule.horaInicio());
        horario.setHoraFin(schedule.horaFin());
        horario.setDisponible(schedule.disponible() == null || schedule.disponible());
        return horario;
    }

    private void validarRangoHorario(LocalTime horaInicio, LocalTime horaFin) {
        if (!horaInicio.isBefore(horaFin)) {
            throw new InvalidHorarioException("horaInicio debe ser anterior a horaFin");
        }
    }

    private DoctorResponse toResponse(Doctor doctor, List<DoctorHorario> horarios) {
        return new DoctorResponse(
                doctor.getId(),
                doctor.getNombre(),
                doctor.getSpecialty().getId(),
                doctor.getSpecialty().getName(),
                doctor.getSpecialty().getConsultationPrice(),
                doctor.getTelefono(),
                doctor.getCorreo(),
                doctor.isActivo(),
                horarios.stream().map(this::toHorarioResponse).toList()
        );
    }

    private DoctorHorarioResponse toHorarioResponse(DoctorHorario horario) {
        return new DoctorHorarioResponse(
                horario.getId(),
                horario.getDoctorId(),
                horario.getDiaSemana(),
                horario.getHoraInicio(),
                horario.getHoraFin(),
                horario.isDisponible()
        );
    }

    private String normalize(String value) {
        return value == null ? "" : value.trim();
    }

    private String blankToNull(String value) {
        String normalized = normalize(value);
        return normalized.isBlank() ? null : normalized;
    }
}
