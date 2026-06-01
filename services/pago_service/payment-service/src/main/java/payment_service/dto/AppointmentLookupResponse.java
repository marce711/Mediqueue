package payment_service.dto;

public record AppointmentLookupResponse(
        String id,
        String patientId,
        String doctorId,
        String appointmentDate,
        String status,
        String createdAt
) {
}
