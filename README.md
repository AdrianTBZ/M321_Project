# 06 Sicherheitsaspekte
[TOC]

## Einleitung
Auch bei verteilten Systemen dreht sich in Bezug auf die Sicherheit alles um die drei Schutzziele (CIA):
* **Confidentiality / Vertraulichkeit:** Die Daten in verteilten Systemen sollten vor unbefugtem Zugriff geschützt werden (beispielsweise durch Authentifizierung und Autorisierung).
* **Integrity / Integrität:** Es soll festgestellt werden können, wenn Daten verändert werden. Änderungen sollten nachvollzogen werden können (beispielsweise in einer Änderungshistorie oder durch Logfiles).
* **Availability / Verfügbarkeit:** Die Systeme sollten dann zur Verfügung stehen, wenn diese benötigt werden. Viele bereits kennen gelernte Massnahmen versuchen durch Failover, Lastenverteilung und Clustering dieses Ziel zu erreichen.

Dieses Kapitel gibt einen Überblick über weitere für die Sicherheit relevanten Aspekte, verweist aber auch an vielen Stellen auf andere Kapitel, wo die konkreten Tools und Massnahmen in anderen Zusammenhängen vorgestellt werden. Ziel dieses Kapitels ist es, dass Sie das bereits gelernte über verteilte Systeme nun vernetzen und die Zusammenhänge zwischen den Teilen mehr und mehr erkennen - insbesondere auch im Zusammenhang mit der Sicherheit Ihrer Applikation.

Zu diesem Kapitel gibt es keine separate Übungsaufgabe. Die Idee ist, dass Sie die hier kennengelernten Konzepte in Ihrer Projektarbeit (LB2) umsetzen und dort vertiefen.

## IAM - Identity and Access Management
Beim IAM (Identity and Access Management) fasst alle die Systemkomponenten zusammen, bei denen es um die Identifizierung und Autorisierung von Benutzern geht. In der Regel wird unterschieden zwischen Systemen, die die Identität der Benutzer überprüfen (Identity Provider oder Autorisierungsserver genannt) und Systemen, die den Zugriff auf die Ressourcen zur Verfügung stellen (auch Ressourcenserver genannt).

Für das Identity and Access Management gibt es einige unterschiedliche Protokolle die eingesetzt werden. Hier eine Auswahl der bekanntesten:
* Kerberos
* SAML (Security Assertion Markup Language): Alternative zu OpenID Connect, XML wird für Protokolldaten eingesetzt
* OpenID Connect (OIDC) und oAuth (oAuth 2.0): OpenID Connect verwendet bzw. erweitert das oAuth-Protokoll

Ein Artikel, der die drei Protokolle miteinander vergleicht, ist unter https://www.kantega-sso.com/articles/the-difference-between-kerberos-saml-og-openid-connect-oidc zu finden.

Diese Protokolle arbeiten teilweise mit sogenannten Tokens. Ein Token ist ein kryptografischer Schlüssel, der mit zusätzlichen Informationen verbunden werden kann. Beispielsweise werden beim JWT (JSON Web Token) - einer konkreten Implementierung eines Tokens - Informationen über die Autorisierung (also die Information auf was zugegriffen werden darf, welche Aktionen ausgeführt werden dürfen und für wie lange) im Token verschlüsselt abgelegt.

Wird JWT eingesetzt, dann wird das Token durch den Autorisierungsserver (AS) ausgestellt, nachdem der Benutzer und dessen Berechtigungen geprüft wurden und dem Benutzer die gewünschten Rechte gewährt werden. Damit der Autorisierungsserver sicherstellen kann, dass niemand seine Tokens fälschen kann, wird das Token mit dem Private-Key des Autorisierungsservers verschlüsselt. Der Ressourcenserver kann dann das Token prüfen, indem er den öffentlichen Schlüssel des Autorisierungsservers verwendet, um die im Token enthaltenen Daten zu prüfen und den Zugriff zu gewähren. Für den Austausch von Schlüsselinformationen wird ein zusätzliches Format "JSON Web Key" (JWK) verwendet. Weiterführende Links zur genauen funktionsweise von JWT sind unter Quellen aufgeführt.


<!--
SAML, OpenID Connect (Erweiterung von oAuth - erweitert die Authentifizierung), 

oAuth: Regelt den Zugriff bzw. Ablauf. Involviert: Autorisierungsserver (AS), Ressourcenserver (RS), Applikation

Die Applikation bezieht beim AS ein Token und die Ressourcen beim RS. Gegenüber des RS authentifiziert sich die Applikation via Token, welches sie vom AS erhalten hat. Der RS validiert das Token beim AS im Hintergrund (aber wie?). Als Format des Tokens kann JWT zum Einsatz kommen.
//-->


## Passwordless Authentication
Bei der passwortlosen Authentifizierung werden keine Passwörter für die Authentifizierung der Benutzer verwendet. In diese Kategorie gehören Lösungen wie beispielsweise:
* **Biometrische Merkmale:** Fingerabdruck, Gesichtserkennung, etc.
* **Hardware Security Token:** Ein physischer Schlüssel (in der Regel in Form eines USB-Sticks oder einer Speicherkarte - in der Regel mit NFC - Near field communication). Dieses physische Device speichert sicher einen Private Key, der dann für die Authentifizierung verwendet wird.
* **Smartphone-Apps:** Apps, die in der Regel auch Private Keys für die Authentifizierung verwalten. Diese Apps sind jedoch in der Regel weniger sicher wie Hardware Security Tokens, weil die Geräte nicht isoliert bzw. speziell geschützt sind und deshalb eine grössere Angriffsfläche bieten.

Weitere Details zur passwortlosen Authentifizierung finden Sie im Artikel https://www.cyberark.com/de/what-is/passwordless-authentication/.

<!--
Notizen (work in progress):
Thema Schlüsselverwaltung und Verteilung könnte ergänzt werden

Verschlüsselung ChatGPT:
In verteilten Systemen gibt es mehrere Schlüsselkomponenten, die für die Verschlüsselung und damit für die Sicherheit der Datenübertragung und -speicherung zuständig sind. Diese Komponenten spielen eine zentrale Rolle bei der Absicherung der Kommunikation und der Gewährleistung der Vertraulichkeit, Integrität und Authentizität der Daten. Die wichtigsten Systemkomponenten im Kontext der Verschlüsselung sind:
1. Schlüsselerzeugung und -verwaltung (Key Management)

    Schlüsselgeneratoren: Erzeugen kryptografische Schlüssel, die für die Ver- und Entschlüsselung verwendet werden. Diese Schlüssel können symmetrisch (gleicher Schlüssel für Ver- und Entschlüsselung) oder asymmetrisch (öffentlich/privat) sein.
    Schlüsselverteilungszentren (Key Distribution Centers, KDC): Verteilen kryptografische Schlüssel sicher an die Teilnehmer eines verteilten Systems.
    Public Key Infrastructure (PKI): Verwaltet öffentliche und private Schlüsselpaare, unterstützt durch digitale Zertifikate, die von einer Zertifizierungsstelle (Certificate Authority, CA) ausgestellt werden.

2. Zertifizierungsstellen (Certificate Authorities, CA)

    Zertifikatserstellung: Stellen digitale Zertifikate aus, die die Authentizität eines öffentlichen Schlüssels bestätigen.
    Zertifikatsverwaltung: Verwalten die Lebensdauer von Zertifikaten, einschließlich der Ausstellung, Verlängerung und dem Widerruf.
    Vertrauenshierarchien: Unterstützen Hierarchien von CAs, die Vertrauen in einer verteilten Umgebung schaffen.

3. Verschlüsselungsalgorithmen

    Symmetrische Verschlüsselung: Verwendet denselben Schlüssel für die Ver- und Entschlüsselung, z. B. AES (Advanced Encryption Standard), DES (Data Encryption Standard).
    Asymmetrische Verschlüsselung: Verwendet ein Schlüsselpaar (privat/öffentlich), z. B. RSA (Rivest-Shamir-Adleman), ECC (Elliptic Curve Cryptography).
    Hybridverschlüsselung: Kombination aus symmetrischer und asymmetrischer Verschlüsselung, bei der ein symmetrischer Schlüssel mithilfe asymmetrischer Verfahren sicher ausgetauscht wird.

4. Verschlüsselungstransporte

    TLS/SSL (Transport Layer Security / Secure Sockets Layer): Verschlüsselt den Datenverkehr zwischen Client und Server, indem es symmetrische Schlüssel aushandelt, die durch asymmetrische Verfahren geschützt werden.
    IPsec (Internet Protocol Security): Verschlüsselt den Datenverkehr auf der Netzwerkschicht, um eine sichere Kommunikation zwischen zwei Netzwerkknoten zu gewährleisten.
    VPN (Virtual Private Network): Schafft verschlüsselte Tunnel zwischen Teilnehmern eines verteilten Systems, um eine sichere Datenübertragung über unsichere Netzwerke zu ermöglichen.

5. Authentifizierungssysteme

    Kerberos: Ein Netzwerk-Authentifizierungsprotokoll, das symmetrische Verschlüsselung und Ticket-basierte Mechanismen verwendet, um sicherzustellen, dass Clients und Server sicher miteinander kommunizieren können.
    OAuth/OpenID Connect: Authentifizierungs- und Autorisierungsprotokolle, die in verteilten Systemen verwendet werden, um die Identität eines Nutzers sicher festzustellen und den Zugriff auf Ressourcen zu verwalten.

6. Sicherer Speicher für Schlüssel (Key Vaults)

    Hardware Security Module (HSM): Spezialisierte Hardware, die kryptografische Schlüssel speichert und manipulationssichere Operationen mit diesen Schlüsseln ermöglicht.
    Key Management Services (KMS): Cloud-basierte oder lokale Systeme, die Schlüssel sicher speichern und verwalten und Zugangskontrolle bieten.

7. Sicherheitsprotokolle für den Nachrichtenaustausch

    PGP (Pretty Good Privacy): Ein Protokoll, das für die Verschlüsselung von E-Mails und Dateien verwendet wird, wobei es auf einer Kombination von asymmetrischer und symmetrischer Kryptographie basiert.
    S/MIME (Secure/Multipurpose Internet Mail Extensions): Ein Standard, der die Verschlüsselung und Signierung von E-Mails ermöglicht.
    Ende-zu-Ende-Verschlüsselung (E2EE): Sicherstellt, dass nur der Sender und der Empfänger die Nachrichten entschlüsseln können, z. B. in Anwendungen wie WhatsApp oder Signal.

8. Integritätsprüfung und Authentifizierung

    Digitale Signaturen: Bieten eine Möglichkeit, die Integrität und Authentizität einer Nachricht zu prüfen, indem die Nachricht mit einem privaten Schlüssel signiert und mit dem öffentlichen Schlüssel verifiziert wird.
    Message Authentication Codes (MAC): Verwendet symmetrische Schlüssel, um die Integrität einer Nachricht zu gewährleisten.
    Hash-Funktionen: Berechnen eindeutige Fingerabdrücke (Hashes) von Nachrichten, um sicherzustellen, dass diese nicht verändert wurden (z. B. SHA-256).

Diese Komponenten arbeiten oft zusammen, um ein ganzheitliches Sicherheitskonzept in verteilten Systemen zu ermöglichen. Jede Komponente trägt dazu bei, entweder die Daten zu verschlüsseln, sicher zu speichern, zu transportieren oder die Identität der Kommunikationspartner zu überprüfen.


//-->

## WAF - Web Application Firewall
Gerade bei veralteten Applikationen ist es nicht immer möglich, die bekannten Schwachstellen auch tatsächlich zu schliessen. In diesen Fällen kann es sinnvoll sein, dass Sie eine WAF (Web Application Firewall) einsetzen, die die Ausnutzung von Schwachstellen verhindert. Die Schwachstellen bleiben dabei in der veralteten Systemkomponente bestehen. Die zusätzliche Systemkomponente (die WAF), die Sie in Ihr verteiltes System einfügen verhindert jedoch, das Angriffe Schaden anrichten können.

**Wichtig:** Auch wenn Sie eine WAF einsetzen, darf das kein Anlass für Sie sein, neue Applikationen ohne Blick auf die Sicherheit umzusetzen. Es darf nicht dazu führen, dass Sie selbst durch unachtsamkeit Schwachstellen schaffen und der Meinung sind, die WAF wird das Problem schon regeln. Die WAF ist als Ergänzung gedacht und soll nicht die generell saubere und sichere Programmierung bei neuen Applikationen oder neuen Applikationsteilen ersetzen.

Damit eine Application Firewall das Gesamtsystem aber wirklich sicherer macht, muss diese richtig konfiguriert werden. Eine Application Firewall muss immer an die Gegebenheiten der konkreten Applikation angepasst werden. Applikationsentwickler kennen ihre Applikationen, die Sie betreuen und müssen entsprechend den Plattformentwicklern beim Einrichten der WAF helfen, dass diese die Ausnutzung der in der Legacy-Applikation vorhandenen Schwachstellen auch tatsächlich stoppt.

Bei WAFs kann auch künstliche Intelligenz (KI) zum Einsatz kommen, um beispielsweise manipulierte Benutzeranfragen zu erkennen und zu blockieren, die beispielsweise XSS oder SQL-Injection zum Ziel haben.

## Einsatz von KI - Segen oder Fluch?
Künstliche Intelligenz (KI) ist gut in der Mustererkennung. Angriffe auf ein verteiltes System (bzw. Angriffe ganz generell) hinterlassen Spuren in den Logfiles und auf den Systemen. Diese Muster sind für Menschen teils sehr schwer zu erkennen. Dabei kann die KI optimal unterstützen.

Die KI kann aber nicht nur beobachtend und berichtend eingesetzt werden. Sie kann auch automatisiert, beim Erkennen von verdächtigem Verhalten, Systeme abschotten bzw. neue Zugriffsregeln definieren, um Bedrohungen einzudämmen oder allenfalls nachdem das verdächtige Verhalten endet die Massnahmen wieder rückgängig zu machen.

Sobald die KI jedoch selbstständig die Sicherheit optimieren kann, öffnet dies neue Türen für Angriffe. Die KI lernt Gut und Böse aufgrund von Trainingsdaten zu unterscheiden. Manchmal lernen die Systeme auch von den Produktivdaten. Gelingt es einem Angreifer die Trainingsdaten so zu manipulieren, dass die KI nicht lernt Angriffe zu verhindern, sondern diese als gutartige Tat anzusehen - als Normalbetrieb - dann kann durch Einsatz von KI mehr Schaden wie Nutzen entstehen.

Ein weiterer Aspekt bei KI ist, dass die KI immer einen "Black-Box"-Charakter hat. Niemand kann mit Bestimmtheit sagen, warum eine KI entscheidet wie sie entschieden hat und ob Sie bei ähnlicher leicht veränderter Datenlage nicht komplett anders entscheidet, weil sie in den Unterschieden ein neues Muster erkennt.

Aus diesen Gründen ist es nie sinnvoll KI in sicherheitsrelevanten Bereichen ohne die ständige Überwachung durch den Menschen in Einsatz zu bringen. Der Mensch muss beurteilen, ob die KI die Daten in den verschiedenen Fällen richtig interpretiert und auch richtig auf mögliche Bedrohungen reagiert. Die KI sollte deshalb als Unterstützung des Menschen und nicht als seinen Ersatz gesehen werden. Dafür stecken die Systeme noch zu sehr in den Kinderschuhen.


<!--
Notizen (Work in progress):
Systemkomponenten zu Autorisierung, Verschlüsselung
Webapplicationfirewalls -> WAF

Einsatz von KI zur Mustererkennung: Überwachung durch Menschen nötig... sonst lässt sich System beim Lernen durch angreifer manipuliere, dass die KI plötzlich mehr Schaden anrichten kann wie das sie nutzen bringt.
Problematik auch: KI = Black-Box. Nicht mehr transparent, warum was wie geschützt wird.
//-->

## Quellen & weiterführende Informationen
* https://www.kantega-sso.com/articles/the-difference-between-kerberos-saml-og-openid-connect-oidc: Artikel, der Kerberos, SAML und OpenID Connect vergleicht
* https://www.okta.com/de/identity-101/what-is-token-based-authentication/: Erklärt die Funktionsweise von JWT
* https://www.okta.com/de/identity-101/whats-the-difference-between-oauth-openid-connect-and-saml/: Ein Vergleich zwischen SAML, oAuth und OIDC
* https://www.clouddna.at/saml-vs-oauth-vs-oidc/: Ein weiterer Vergleich zwischen SAML, oAuth und OIDC (nicht von okta wie die beiden vorangehenden Quellen, sondern von clouddna)
* https://www.cloudflare.com/de-de/learning/access-management/what-is-an-identity-provider/: Artikel von Cloudflare, der erklärt, was ein Identity Provider ist
* https://de.wikipedia.org/wiki/Identit%C3%A4tsanbieter: Wikipedia zu Identity Provider
* https://de.wikipedia.org/wiki/Web_Application_Firewall: Wikipedia-Artikel zum Thema Web Application Firewall
* https://www.oracle.com/ch-de/security/cloud-security/what-is-waf/: Beschreibung von Oracle was eine WAF ist
* https://flexa.cloud/de/waf-was-ist-und-wie-aws-web-application-firewall-funktioniert/: Artikel der sich mit der WAF von AWS beschäftigt
* https://aws.amazon.com/de/waf/: Beschreibung zur AWS WAF von Amazon selbst

<!--
Notizen (work in progress):
Quellen zu KI und verteilten Systemen im Zusammenhang mit IDS/IPS und WAF suchen
Quellen zu IAM Themen suchen (OpenAPI, JWT, oAuth)
//-->