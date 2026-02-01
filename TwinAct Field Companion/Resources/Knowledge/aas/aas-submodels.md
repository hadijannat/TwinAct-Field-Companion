# Standard AAS Submodel Templates

## Overview

The Industrial Digital Twin Association (IDTA) publishes standardized submodel templates that ensure consistent data structures across implementations. Using these templates enables interoperability and simplifies integration.

## Digital Nameplate (IDTA 02006)

**Purpose:** Provides the electronic equivalent of a physical nameplate - manufacturer information, product identification, and regulatory markings.

**Key Elements:**
- `ManufacturerName` - Company name
- `ManufacturerProductDesignation` - Product type/model
- `SerialNumber` - Unique instance identifier
- `YearOfConstruction` - Manufacturing year
- `DateOfManufacture` - Specific manufacturing date
- `ContactInformation` - Manufacturer contact details
- `Markings` - Regulatory markings (CE, UL, etc.)

**Field Use:** Quickly identify any asset by scanning its QR code and viewing the digital nameplate.

## Carbon Footprint (IDTA 02029)

**Purpose:** Provides environmental impact data aligned with DPP requirements.

**Key Elements:**
- `ProductCarbonFootprint` (PCF) - Manufacturing emissions
  - `PCFCO2eq` - Total CO2 equivalent in kg
  - `PCFCalculationMethod` - GHG Protocol, ISO 14067, etc.
  - `PCFReferenceValueForCalculation` - Functional unit
- `TransportCarbonFootprint` (TCF) - Distribution emissions
- `UsePhaseCarbonFootprint` (UCF) - Operational emissions estimate
- `EndOfLifeCarbonFootprint` (EOLCF) - Disposal/recycling emissions
- `ThirdPartyVerification` - Independent verification details

**Field Use:** Compare environmental impact of alternative products; verify carbon footprint claims.

## Handover Documentation (IDTA 02004)

**Purpose:** Organizes all technical documentation for an asset.

**Document Categories:**
- Operating Instructions
- Assembly Instructions
- Safety Instructions
- Maintenance Instructions
- Technical Drawings
- Certificates and Declarations
- Test Reports
- Spare Parts Lists

**Key Elements:**
- `Document` collection with:
  - `DocumentId` - Unique document identifier
  - `DocumentClassification` - Type classification
  - `DocumentVersion` - Version number
  - `Title` - Multi-language title
  - `Summary` - Multi-language description
  - `DigitalFile` - File references (PDF, etc.)

**Field Use:** Access manuals, certificates, and maintenance instructions directly from the asset.

## Technical Data (IDTA 02003)

**Purpose:** Provides operating specifications and performance data.

**Key Elements:**
- `GeneralInformation` - Overview and classification
- `ProductClassifications` - ECLASS, UNSPSC codes
- `TechnicalProperties` - Specifications
  - Electrical ratings (voltage, current, power)
  - Mechanical specifications (dimensions, weight)
  - Environmental conditions (temperature, humidity)
  - Performance characteristics

**Field Use:** Verify operating conditions; check compatibility with installation requirements.

## Hierarchical Structures (IDTA 02011)

**Purpose:** Defines bill of materials and component relationships.

**Key Elements:**
- `ArcheType` - Full structure or one-to-many
- `EntryNode` - Root component
- `Node` collections with:
  - `HasPart` relationships (composition)
  - `IsPartOf` relationships (containment)
  - `SameAs` relationships (equivalence)

**Field Use:** Understand component hierarchy; identify spare parts; trace subassemblies.

## Contact Information (IDTA 02002)

**Purpose:** Structured contact details for various roles.

**Key Elements:**
- `ContactType` - Role (manufacturer, service, sales)
- `Company` - Organization name
- `Department` - Business unit
- `Phone` - Phone numbers with type
- `Email` - Email addresses
- `Address` - Postal address
- `Website` - Company URL

**Field Use:** Contact manufacturer support; reach service providers.

## Time Series Data (IDTA 02008)

**Purpose:** Records sensor readings and operational data over time.

**Key Elements:**
- `Record` - Data point structure definition
- `Segment` - Collection of records
- `TimeSeries` - Complete data sequence
- `InternalLink` / `ExternalLink` - Data storage references

**Linked Data Types:**
- Sensor measurements
- Production counters
- Quality metrics
- Error logs

**Field Use:** View operational history; analyze trends; diagnose issues.

## Software Nameplate (IDTA 02019)

**Purpose:** Documents software and firmware components.

**Key Elements:**
- `SoftwareNameplate` collection:
  - `SoftwareName` - Application name
  - `SoftwareVersion` - Version identifier
  - `BuildDate` - Compilation date
  - `InstallDate` - Installation date
  - `SoftwareType` - Category (firmware, application, library)
  - `ReleaseNotes` - Change documentation

**Field Use:** Verify firmware versions; track software updates; ensure compatibility.
