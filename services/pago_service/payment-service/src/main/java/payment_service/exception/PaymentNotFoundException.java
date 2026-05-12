package payment_service.exception;

public class PaymentNotFoundException extends RuntimeException {

    public PaymentNotFoundException(Long id) {
        super("Pago no encontrado con id: " + id);
    }
}
