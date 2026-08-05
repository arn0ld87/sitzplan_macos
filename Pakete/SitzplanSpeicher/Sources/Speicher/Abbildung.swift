import Domain
import Foundation

// Abbildung `@Model` → Domänenwert. Genau eine Stelle, damit sie pruefbar ist.
//
// Die Richtung ist bewusst einseitig: Aus dem Speicher kommen Werte heraus, in
// den Speicher gehen Aenderungen ueber die Repository-Methoden hinein. Ein
// „speichere dieses Domaenenobjekt“ waere bequemer und wuerde die Regel
// unterlaufen, dass ein Loeschzeitpunkt nur an einer Stelle gesetzt wird.

extension KlassenEintrag {
    public func alsDomaene() -> Klasse {
        Klasse(
            id: id,
            name: name,
            notizen: notizen,
            erstelltAm: erstelltAm,
            geaendertAm: geaendertAm,
            geloeschtAm: geloeschtAm
        )
    }
}

extension SchuelerEintrag {
    public func alsDomaene() -> Schueler {
        Schueler(
            id: id,
            klasseId: klasse?.id ?? UUID(),
            vorname: vorname,
            nachname: nachname,
            initialen: initialen,
            farbIndex: farbIndex,
            // Unbekannte Rohwerte fallen hier heraus, bleiben aber im Speicher
            // stehen — siehe `merkmaleRoh`.
            merkmale: merkmaleRoh.compactMap(Merkmal.init(rawValue:)),
            notiz: notiz,
            erstelltAm: erstelltAm,
            geaendertAm: geaendertAm,
            geloeschtAm: geloeschtAm
        )
    }
}

extension SitzregelEintrag {
    public func alsDomaene() -> Sitzregel {
        Sitzregel(
            id: id,
            klasseId: klasse?.id ?? UUID(),
            schuelerA: schuelerA,
            schuelerB: schuelerB,
            art: Regelart(rawValue: artRoh) ?? .nichtNeben,
            erstelltAm: erstelltAm,
            geaendertAm: geaendertAm,
            geloeschtAm: geloeschtAm
        )
    }
}

extension RaumEintrag {
    public func alsDomaene() -> Raum {
        Raum(
            id: id,
            name: name,
            breiteCm: breiteCm,
            laengeCm: laengeCm,
            rasterCm: rasterCm,
            dokument: dokument,
            dokumentVersion: dokumentVersion,
            erstelltAm: erstelltAm,
            geaendertAm: geaendertAm,
            geloeschtAm: geloeschtAm
        )
    }
}

extension SitzplanEintrag {
    public func alsDomaene() -> Sitzplan {
        Sitzplan(
            id: id,
            klasseId: klasseId,
            raumId: raumId,
            name: name,
            status: Planstatus(rawValue: statusRoh) ?? .entwurf,
            dokument: dokument,
            dokumentVersion: dokumentVersion,
            erstelltAm: erstelltAm,
            geaendertAm: geaendertAm,
            geloeschtAm: geloeschtAm
        )
    }
}
