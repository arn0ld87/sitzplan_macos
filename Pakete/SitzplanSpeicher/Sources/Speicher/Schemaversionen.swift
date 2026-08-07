import Domain
import Foundation
import SwiftData

// Schemaversionen und ihr Migrationsplan.
//
// Warum das schon in der ersten Fassung steht, obwohl es nur eine Version gibt:
// Ohne Server ist die Datenbank der Lehrkraft die einzige Kopie ihrer Daten.
// Eine Aenderung an einem `@Model`-Typ ohne Migrationsplan macht sie unlesbar,
// und es gibt niemanden, von dem sie sich neu laden liesse.
//
// Ein `VersionedSchema` nachtraeglich einzufuehren, wenn der Store schon
// draussen ist, ist die unangenehmste Variante. Deshalb von Anfang an — auch
// wenn `migrationPlan` heute leer ist. Siehe ADR-0002, Abschnitt „Kein Backend“.

/// Die erste ausgelieferte Fassung des Schemas.
public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: SwiftData.Schema.Version { .init(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            KlassenEintrag.self,
            SchuelerEintrag.self,
            SitzregelEintrag.self,
            RaumEintrag.self,
            SitzplanEintrag.self,
            SitzplanVersionEintrag.self,
        ]
    }
}

/// Der Migrationsplan.
///
/// Solange es nur eine Version gibt, sind `schemas` einelementig und `stages`
/// leer. Beim naechsten Schritt kommt eine `SchemaV2` hinzu **und** eine Stufe,
/// die V1 darauf abbildet — beides zusammen, nie nur das eine.
///
/// - Important: Eine leichtgewichtige Migration (`.lightweight`) traegt nur
///   additive Aenderungen. Ein umbenanntes oder anders typisiertes Feld braucht
///   `.custom` mit `willMigrate`/`didMigrate`. Im Zweifel `.custom` — ein
///   verlorenes Feld faellt hier niemandem auf, bis eine Lehrkraft ihre Klassen
///   vermisst.
public enum Migrationsplan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
