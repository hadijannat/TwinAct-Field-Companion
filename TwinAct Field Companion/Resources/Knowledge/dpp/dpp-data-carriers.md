# DPP Data Carriers and Identifiers

## Data Carrier Requirements

A data carrier is the physical element on a product that provides access to the Digital Product Passport. Per ESPR Article 8, data carriers must be:

- **Durable:** Readable throughout the product's expected lifetime
- **Accessible:** Easily locatable by consumers and professionals
- **Machine-readable:** Scannable without specialized equipment
- **Standardized:** Following recognized international standards

## QR Codes

QR codes are the primary data carrier for most consumer products.

### Technical Specifications
- **Format:** ISO/IEC 18004 QR Code
- **Error Correction:** Level M (15%) or higher recommended
- **Minimum Size:** Ensure readability at arm's length (typically 15mm+)
- **Quiet Zone:** Maintain required margin around code
- **Contrast:** High contrast for reliable scanning

### Content Format
QR codes contain a URL pointing to the DPP data:
```
https://dpp.example.com/passport/{unique-identifier}
```

### Placement Guidelines
- Permanently affixed to product
- Visible without disassembly
- Protected from wear and damage
- Not obscured by packaging (or duplicated on packaging)

## Unique Product Identifiers

Every product instance requires a globally unique identifier linking physical product to digital passport.

### GS1 Digital Link
Recommended standard for consumer products:
```
https://id.gs1.org/01/09521234543213/21/ABC123
```
- `01/` - GTIN (Global Trade Item Number)
- `21/` - Serial number

### DID (Decentralized Identifiers)
Emerging standard for decentralized systems:
```
did:web:example.com:passports:12345
```

### IRI Format (AAS)
Standard AAS identifier format:
```
https://example.com/aas/products/motor-abc-12345
```

## Multiple Data Carrier Support

Products may have multiple data carriers for different purposes:

### Product Label
- Main QR code linking to full DPP
- Human-readable identifier

### Packaging
- Duplicate QR for initial access
- Recycling-specific code

### Documentation
- QR linking to digital manuals
- Warranty registration codes

## Data Carrier Security

### Anti-Counterfeiting
- Serialized identifiers enable authenticity verification
- Blockchain anchoring for tamper evidence (optional)
- Digital signatures on DPP data

### Data Integrity
- Checksum validation
- Digital certificates
- Audit trails for modifications

## Interoperability Requirements

### Resolver Services
Data carriers point to resolver services that direct to authoritative data sources:

1. Scan QR code
2. Resolver interprets identifier
3. Redirects to current DPP location
4. DPP data returned in standard format

### Standard Protocols
- **HTTP/HTTPS:** Primary access protocol
- **REST APIs:** Structured data access
- **JSON-LD:** Linked data format
- **AAS API:** Industry 4.0 standard interface

## Offline Access

For products used in environments without network access:

### AASX Packages
Complete DPP data can be embedded in AASX files stored locally or on devices.

### NFC Tags
Near-field communication tags can store:
- Offline identifier
- Basic product information
- Link for online access when available

### Embedded Storage
Some products (electronics) may store DPP data internally, accessible via diagnostic interfaces.

## Regulatory Requirements

### ESPR Article 8(2)
The data carrier shall:
- Be physically present on the product
- Clearly visible to consumers
- Accessible before and after purchase
- Link to information in accessible format

### Battery Regulation
Battery passports require QR codes meeting:
- Minimum 15mm dimension
- Durability for battery lifetime
- Accessibility without battery removal
