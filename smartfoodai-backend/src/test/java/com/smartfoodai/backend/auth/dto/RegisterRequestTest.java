package com.smartfoodai.backend.auth.dto;

import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;

class RegisterRequestTest {
    private static ValidatorFactory factory;
    private static Validator validator;

    @BeforeAll
    static void setUp() {
        factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @AfterAll
    static void close() {
        factory.close();
    }

    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = {" ", "sin-arroba", "@example.com", "persona@", "a b@example.com"})
    void rejectsMissingOrMalformedEmail(String email) {
        assertThat(validator.validate(new RegisterRequest(email, "abcdefgh")))
                .anyMatch(error -> error.getPropertyPath().toString().equals("email"));
    }

    @Test
    void rejectsEmailLongerThanStoragePolicy() {
        String email = "a".repeat(64) + "@" + "b".repeat(63) + "."
                + "c".repeat(63) + "." + "d".repeat(61);
        assertThat(email).hasSize(255);
        assertThat(validator.validate(new RegisterRequest(email, "abcdefgh"))).isNotEmpty();
    }

    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = {"        ", "1234567", "😀😀😀😀"})
    void rejectsMissingBlankOrShortPassword(String password) {
        assertThat(validator.validate(new RegisterRequest("persona@example.com", password))).isNotEmpty();
    }

    @ParameterizedTest
    @ValueSource(strings = {"abcdefgh", "12345678", "áéíóúñab", "😀😀😀😀😀😀😀😀", " abcdef "})
    void acceptsEightCharactersWithoutRequiringLettersAndNumbers(String password) {
        var request = new RegisterRequest("persona@example.com", password);
        assertThat(validator.validate(request)).isEmpty();
        assertThat(request.password()).isEqualTo(password);
    }

    @ParameterizedTest
    @ValueSource(strings = {"a", "ñ", "😀"})
    void acceptsExactly72Utf8BytesAndRejectsOverflowWithoutTruncation(String character) {
        int bytesPerCharacter = character.getBytes(java.nio.charset.StandardCharsets.UTF_8).length;
        String boundary = character.repeat(72 / bytesPerCharacter);
        assertThat(validator.validate(new RegisterRequest("persona@example.com", boundary))).isEmpty();

        var overflowing = new RegisterRequest("persona@example.com", boundary + "a");
        assertThat(validator.validate(overflowing))
                .anyMatch(error -> error.getPropertyPath().toString().equals("passwordWithinByteLimit"));
        assertThat(overflowing.password()).isEqualTo(boundary + "a");
    }
}
