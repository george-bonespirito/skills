import com.lemonappdev.konsist.api.Konsist
import com.lemonappdev.konsist.api.ext.list.withNameEndingWith
import com.lemonappdev.konsist.api.verify.assertTrue
import org.junit.jupiter.api.Test

/**
 * Smoke test: drives the Konsist public API against this project's own Kotlin.
 * Proves the library scopes source, filters declarations, and verifies a rule.
 */
class SmokeKonsistTest {

    @Test
    fun `konsist scopes the project and finds Kotlin files`() {
        val files = Konsist.scopeFromProject().files
        check(files.isNotEmpty()) { "Konsist scoped no files — scope resolution broken" }
    }

    @Test
    fun `UseCase classes reside in a domain package`() {
        Konsist
            .scopeFromProject()
            .classes()
            .withNameEndingWith("UseCase")
            .assertTrue { it.resideInPackage("..domain..") }
    }
}
