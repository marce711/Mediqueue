package com.mediqueue.cita_service.controller;

import com.mediqueue.cita_service.dto.AppointmentRequest;
import com.mediqueue.cita_service.dto.AppointmentResponse;
import com.mediqueue.cita_service.dto.AppointmentUpdateRequest;
import com.mediqueue.cita_service.dto.AvailabilityResponse;
import com.mediqueue.cita_service.service.AppointmentService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Validated
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/appointments")
public class AppointmentController {

    private final AppointmentService appointmentService;

    @PostMapping
    public ResponseEntity<AppointmentResponse> create(
            @Valid @RequestBody AppointmentRequest request,
            @RequestHeader(name = "Idempotency-Key", required = false) String idempotencyKey
    ) {
        return ResponseEntity.status(HttpStatus.CREATED).body(appointmentService.create(request, idempotencyKey));
    }

    @GetMapping
    public ResponseEntity<List<AppointmentResponse>> findAll(
            @RequestParam(required = false) String doctorId,
            @RequestParam(required = false) String patientId
    ) {
        return ResponseEntity.ok(appointmentService.findAll(doctorId, patientId));
    }

    @GetMapping("/{id}")
    public ResponseEntity<AppointmentResponse> findById(@PathVariable UUID id) {
        return ResponseEntity.ok(appointmentService.findById(id));
    }

    @GetMapping("/availability")
    public ResponseEntity<AvailabilityResponse> checkAvailability(
            @RequestParam @NotBlank(message = "doctorId is required") String doctorId,
            @RequestParam
            @NotNull(message = "appointmentDate is required")
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME)
            LocalDateTime appointmentDate,
            @RequestParam(required = false, defaultValue = "30") Integer durationMinutes
    ) {
        return ResponseEntity.ok(appointmentService.checkAvailability(doctorId, appointmentDate, durationMinutes));
    }

    @PatchMapping("/{id}/status")
    public ResponseEntity<AppointmentResponse> updateStatus(
            @PathVariable UUID id,
            @Valid @RequestBody AppointmentUpdateRequest request
    ) {
        return ResponseEntity.ok(appointmentService.updateStatus(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<AppointmentResponse> cancel(@PathVariable UUID id) {
        return ResponseEntity.ok(appointmentService.cancel(id));
    }
}
