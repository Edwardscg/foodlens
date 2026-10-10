package com.smartfoodai.backend.meals.service;

import com.smartfoodai.backend.common.exception.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import javax.imageio.ImageIO;
import java.awt.Color;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Set;

@Service
public class MealImageSanitizer {
    public byte[] sanitize(MultipartFile file) {
        if (file == null || file.isEmpty()) throw invalid("Selecciona una fotografía.");
        if (file.getSize() > 5 * 1024 * 1024) throw invalid("La imagen no debe superar 5 MB.");
        try (var input = ImageIO.createImageInputStream(new ByteArrayInputStream(file.getBytes()))) {
            var readers = ImageIO.getImageReaders(input);
            if (!readers.hasNext()) throw invalid("Usa una imagen JPEG o PNG válida.");
            var reader = readers.next();
            try {
                if (!Set.of("JPEG", "PNG").contains(reader.getFormatName().toUpperCase(java.util.Locale.ROOT))) {
                    throw invalid("Usa una imagen JPEG o PNG.");
                }
                reader.setInput(input, true, true);
                int width = reader.getWidth(0), height = reader.getHeight(0);
                if (width <= 0 || height <= 0 || (long) width * height > 12_000_000) {
                    throw invalid("La imagen admite hasta 12 megapíxeles.");
                }
                var source = reader.read(0);
                double factor = Math.min(1.0, 1600.0 / Math.max(width, height));
                var clean = new BufferedImage(Math.max(1, (int) (width * factor)),
                        Math.max(1, (int) (height * factor)), BufferedImage.TYPE_INT_RGB);
                var graphics = clean.createGraphics();
                try {
                    graphics.setColor(Color.WHITE);
                    graphics.fillRect(0, 0, clean.getWidth(), clean.getHeight());
                    graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
                    graphics.drawImage(source, 0, 0, clean.getWidth(), clean.getHeight(), null);
                } finally { graphics.dispose(); source.flush(); }
                try (var output = new ByteArrayOutputStream()) {
                    if (!ImageIO.write(clean, "JPEG", output)) throw invalid("No pudimos preparar la imagen.");
                    // Re-encoding removes original metadata; filenames and EXIF never reach Gemini.
                    return output.toByteArray();
                } finally { clean.flush(); }
            } finally { reader.dispose(); }
        } catch (IOException | IllegalArgumentException exception) {
            throw invalid("No pudimos leer la imagen. Elige otra fotografía.");
        }
    }

    private ApiException invalid(String message) { return new ApiException(HttpStatus.BAD_REQUEST, message); }
}
