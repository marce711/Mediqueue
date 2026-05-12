package com.mediqueue.notificacion.controller;

import com.mediqueue.notificacion.dto.NotificationResponse;
import com.mediqueue.notificacion.service.NotificationService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/notificaciones")
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping
    public ResponseEntity<List<NotificationResponse>> findRecent() {
        return ResponseEntity.ok(notificationService.findRecent());
    }
}
