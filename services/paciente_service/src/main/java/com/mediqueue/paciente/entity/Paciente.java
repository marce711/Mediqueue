package com.mediqueue.paciente.entity;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(
        name = "pacientes",
        indexes = {
                @Index(name = "idx_dpi", columnList = "dpi", unique = true)
        }
)
public class Paciente {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "id_paciente")
    private UUID id;

    @Column(unique = true, nullable = false)
    private String dpi;

    @Column(unique = true, nullable = false)
    private String correo;

    @Column(nullable = false)
    private String nombre;

    @Column(nullable = false)
    private String telefono;

    @Column(name = "estado", nullable = false)
    private String estado = "ACTIVO";

    // Constructor vacío obligatorio
    public Paciente() {
    }

    // Getters y Setters

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public String getDpi() {
        return dpi;
    }

    public void setDpi(String dpi) {
        this.dpi = dpi;
    }

    public String getCorreo() {
        return correo;
    }

    public void setCorreo(String correo) {
        this.correo = correo;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getTelefono() {
        return telefono;
    }

    public void setTelefono(String telefono) {
        this.telefono = telefono;
    }

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }
}
