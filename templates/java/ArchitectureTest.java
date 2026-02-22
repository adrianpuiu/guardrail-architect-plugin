package arch;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;
import static com.tngtech.archunit.library.Architectures.layeredArchitecture;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;

/**
 * Guardrail Architect — Architecture Tests (ArchUnit)
 * These tests enforce dependency rules as executable specs.
 * Violations fail the build — agents can't break architecture silently.
 *
 * Add dependency: com.tngtech.archunit:archunit-junit5:1.3.0
 */
class ArchitectureTest {

    private static JavaClasses classes;

    @BeforeAll
    static void setup() {
        classes = new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .importPackages("com.yourcompany.project"); // ← Change to your base package
    }

    @Test
    void layered_architecture_is_respected() {
        layeredArchitecture()
            .consideringAllDependencies()
            .layer("Controllers").definedBy("..api..", "..controller..", "..rest..")
            .layer("Services").definedBy("..service..")
            .layer("Repositories").definedBy("..repository..", "..persistence..")
            .layer("Domain").definedBy("..domain..", "..model..")
            .whereLayer("Controllers").mayOnlyAccessLayers("Services", "Domain")
            .whereLayer("Services").mayOnlyAccessLayers("Repositories", "Domain")
            .whereLayer("Repositories").mayOnlyAccessLayers("Domain")
            .whereLayer("Domain").mayNotAccessAnyLayer()
            .check(classes);
    }

    @Test
    void no_circular_dependencies() {
        slices()
            .matching("com.yourcompany.project.(*)..")
            .should().beFreeOfCycles()
            .check(classes);
    }

    @Test
    void domain_must_not_depend_on_infrastructure() {
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAnyPackage("..infrastructure..", "..persistence..", "..api..")
            .because("Domain layer must be pure — no framework dependencies")
            .check(classes);
    }

    @Test
    void controllers_must_not_access_repositories_directly() {
        noClasses()
            .that().resideInAnyPackage("..api..", "..controller..")
            .should().dependOnClassesThat()
            .resideInAPackage("..repository..")
            .because("Controllers must go through services, not directly to repositories")
            .check(classes);
    }

    @Test
    void services_should_be_annotated() {
        classes()
            .that().resideInAPackage("..service..")
            .and().areNotInterfaces()
            .should().beAnnotatedWith("org.springframework.stereotype.Service")
            .orShould().beAnnotatedWith("jakarta.inject.Named")
            .because("Service classes should be explicitly marked for DI")
            .check(classes);
    }
}
