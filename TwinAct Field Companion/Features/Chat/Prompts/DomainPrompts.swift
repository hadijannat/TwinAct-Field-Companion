//
//  DomainPrompts.swift
//  TwinAct Field Companion
//
//  Centralized domain expertise prompts for the AI Chat assistant.
//  Contains comprehensive knowledge about AAS, DPP, and EU regulations.
//

import Foundation

// MARK: - Domain Prompts

/// Centralized domain expertise for the AI Chat assistant
public enum DomainPrompts {

    // MARK: - Core System Prompt

    /// Base system prompt establishing AI assistant identity and expertise
    public static let baseSystemPrompt = """
    You are a knowledgeable assistant for field technicians working with Industrial Digital Twins. \
    You have deep expertise in:

    - Asset Administration Shell (AAS) and the IDTA metamodel
    - Digital Product Passports (DPP) as defined by EU ESPR
    - EU sustainability regulations (ESPR, Battery Regulation, Machinery Regulation)
    - EU AI Act requirements for industrial AI systems
    - Compliance frameworks (RoHS, WEEE, REACH, CE marking)

    When answering questions:
    - Cite specific regulation articles when applicable (e.g., "per ESPR Article 8")
    - Distinguish between mandatory requirements and guidance/best practices
    - Note effective dates and transition periods for regulations
    - Acknowledge uncertainty about pending or draft regulations
    - Be concise and technical, suitable for field technicians
    - Reference specific procedures or warnings when relevant
    """

    // MARK: - AAS Expertise

    /// Comprehensive AAS domain knowledge
    public static let aasExpertise = """
    ## Asset Administration Shell (AAS) Expertise

    ### Metamodel Structure
    The AAS metamodel (IDTA 01001-3-0) defines:
    - **Asset**: The physical or logical thing being described
    - **AAS**: The digital representation containing all information
    - **Submodel**: Thematic groupings of properties (e.g., Nameplate, CarbonFootprint)
    - **SubmodelElement**: Individual data points within submodels (Property, Collection, File, etc.)
    - **ConceptDescription**: Semantic definitions for data elements
    - **Semantic IDs**: Globally unique identifiers linking to standard definitions

    ### Key Submodel Templates (IDTA Standards)
    - **Digital Nameplate (IDTA 02006)**: Manufacturer, serial number, product markings
    - **Handover Documentation (IDTA 02004)**: Technical documents, manuals, certificates
    - **Carbon Footprint (IDTA 02029)**: PCF, TCF, UCF phases with CO2eq values
    - **Technical Data (IDTA 02003)**: Operating conditions, performance specs
    - **Hierarchical Structures (IDTA 02011)**: Bill of materials, component relationships
    - **Contact Information (IDTA 02002)**: Manufacturer contact details
    - **Time Series Data (IDTA 02008)**: Sensor readings, operational data
    - **Software Nameplate (IDTA 02019)**: Firmware versions, software components

    ### AASX Package Format
    AASX files follow OPC (Open Packaging Conventions, ISO/IEC 29500-2):
    - ZIP container with standardized structure
    - `_rels/.rels` defines relationships
    - `aasx/aas.json` or `aas.xml` contains the AAS/Submodel data
    - Supplementary files (PDFs, images) referenced via relationships
    - Content types defined in `[Content_Types].xml`

    ### AAS API Specification (IDTA 01002)
    Standard REST endpoints:
    - `GET /shells` - List all AAS
    - `GET /shells/{aasId}` - Get specific AAS
    - `GET /submodels` - List submodels
    - `GET /submodels/{smId}/submodel-elements` - Get submodel elements
    - Discovery via `GET /lookup/shells?assetIds=...`
    """

    // MARK: - DPP Expertise

    /// Comprehensive DPP domain knowledge
    public static let dppExpertise = """
    ## Digital Product Passport (DPP) Expertise

    ### ESPR Framework (Regulation 2024/1781)
    The Ecodesign for Sustainable Products Regulation establishes DPP requirements:
    - **Scope**: Applies to products placed on EU market (excluding food, feed, medicinal products)
    - **Data Carriers**: QR codes linking to DPP data (mandatory for most products)
    - **Unique Product Identifiers**: Each product instance must be uniquely identifiable
    - **Interoperability**: Based on open standards (AAS selected as technical foundation)

    ### DPP Data Categories
    Per ESPR Article 8, DPPs must provide:
    1. **Product identification**: Unique IDs, model, batch/serial numbers
    2. **Compliance information**: Conformity declarations, notified body details
    3. **Sustainability attributes**: Carbon footprint, recycled content, durability
    4. **Material composition**: Substances of concern, critical raw materials
    5. **Repair information**: Spare parts, repair manuals, professional repairer access
    6. **End-of-life**: Disassembly instructions, recycling information

    ### Implementation Timeline
    - **2024**: ESPR entered into force (July 18, 2024)
    - **2026**: First delegated acts specifying product categories expected
    - **2027-2030**: Phased rollout by product category (batteries first)
    - **2030+**: Full coverage of priority product groups

    ### Data Carrier Requirements
    - **QR codes**: Primary carrier for consumer products
    - **Machine-readable**: Must link to standardized data format
    - **Durability**: Must remain readable throughout product lifecycle
    - **Accessibility**: Consumer-facing and B2B data access levels

    ### Relationship to AAS
    DPP requirements align with AAS submodels:
    - Digital Nameplate -> Product identification
    - Carbon Footprint -> Sustainability attributes
    - Handover Documentation -> Repair/compliance information
    - Material Composition -> Substances data
    """

    // MARK: - ESPR Expertise

    /// Detailed ESPR regulatory knowledge
    public static let esprExpertise = """
    ## ESPR Regulation Expertise

    ### Key Provisions
    **Article 4 - Ecodesign Requirements**: Products must meet requirements for:
    - Durability and reliability
    - Reusability and upgradability
    - Repairability and maintenance
    - Presence of substances of concern
    - Energy and resource efficiency
    - Recycled content and recyclability
    - Carbon and environmental footprint

    **Article 8 - Digital Product Passport**:
    - Mandatory for products covered by delegated acts
    - Must include unique identifier linked to data carrier
    - Information accessible to consumers, repair professionals, and authorities
    - Different access levels for different stakeholders

    **Article 21 - Right to Repair**:
    - Spare parts must be available for minimum period
    - Repair information accessible to independent repairers
    - No technical barriers to repair (anti-circumvention)
    - Software updates for reasonable period

    ### Delegated Acts (Expected Product Categories)
    1. **Textiles and footwear** (high priority)
    2. **Furniture** (including mattresses)
    3. **Iron and steel** (intermediate products)
    4. **Aluminium** (intermediate products)
    5. **Chemicals** (including detergents, paints)
    6. **Electronics** (ICT equipment)
    7. **Batteries** (already covered by Battery Regulation)
    8. **Construction products** (coordination with CPR)

    ### Penalties and Enforcement
    - Member states must establish penalties (effective, proportionate, dissuasive)
    - Market surveillance authorities can remove non-compliant products
    - Customs authorities can refuse entry of non-compliant imports
    """

    // MARK: - EU AI Act Expertise

    /// Comprehensive EU AI Act knowledge
    public static let euAIActExpertise = """
    ## EU AI Act Expertise (Regulation 2024/1689)

    ### Risk Classification Tiers
    The AI Act categorizes AI systems by risk level:

    **Unacceptable Risk (Prohibited)**:
    - Social scoring by governments
    - Real-time remote biometric identification in public (with exceptions)
    - Subliminal manipulation causing harm
    - Exploitation of vulnerabilities (age, disability)

    **High-Risk** (Article 6):
    Two categories of high-risk AI systems:
    1. Safety components of products under EU harmonization legislation
    2. AI systems in Annex III areas:
       - Biometric identification
       - Critical infrastructure (water, gas, electricity)
       - Education and vocational training
       - Employment and worker management
       - Essential services access (credit, insurance)
       - Law enforcement
       - Migration and asylum
       - Justice administration

    **Limited Risk**:
    - Transparency obligations (chatbots, deepfakes)
    - Users must be informed they're interacting with AI

    **Minimal Risk**:
    - No specific requirements (spam filters, AI-enabled games)

    ### High-Risk AI Requirements (Articles 8-15)
    - **Risk management system** (ongoing throughout lifecycle)
    - **Data governance** (training data quality, bias testing)
    - **Technical documentation** (detailed system description)
    - **Record-keeping** (automatic logging for traceability)
    - **Transparency** (instructions for use, limitations)
    - **Human oversight** (appropriate human control measures)
    - **Accuracy, robustness, cybersecurity** (appropriate performance levels)

    ### Conformity Assessment
    - Self-assessment for most high-risk systems
    - Third-party assessment for certain biometric systems
    - CE marking required before market placement
    - Registration in EU database for high-risk systems

    ### Timeline
    - **August 2024**: Entered into force
    - **February 2025**: Prohibited AI practices applicable
    - **August 2025**: General-purpose AI rules applicable
    - **August 2026**: Full applicability (high-risk rules)
    - **August 2027**: Certain embedded AI systems rules

    ### Industrial AI Considerations
    AI systems in industrial machinery may be high-risk if:
    - Used as safety components in machinery (Machinery Regulation)
    - Control critical infrastructure operations
    - Make employment-related decisions

    Note: General-purpose AI for field assistance typically falls under transparency \
    requirements unless integrated into high-risk applications.
    """

    // MARK: - Battery Regulation Expertise

    /// Battery Regulation knowledge
    public static let batteryRegulationExpertise = """
    ## Battery Regulation Expertise (Regulation 2023/1542)

    ### Scope and Categories
    Applies to all batteries placed on EU market:
    - **Portable batteries** (weight ≤5 kg, non-industrial)
    - **LMT batteries** (light means of transport: e-bikes, scooters)
    - **SLI batteries** (starting, lighting, ignition - vehicles)
    - **Industrial batteries** (>5 kWh, industrial applications)
    - **EV batteries** (electric vehicle traction batteries)

    ### Battery Passport Requirements (Article 77)
    Mandatory for industrial and EV batteries from February 2027:
    - Unique identifier (QR code with data carrier)
    - Performance data (capacity, state of health, expected lifetime)
    - Carbon footprint (from Feb 2025 for EV/industrial)
    - Material composition (cobalt, lead, lithium, nickel content)
    - Recycled content information
    - Supply chain due diligence summary
    - End-of-life information

    ### Carbon Footprint Requirements
    **Phase 1** (Feb 2025): Declaration of carbon footprint
    **Phase 2** (Feb 2026): Performance classes (A-G or similar)
    **Phase 3** (Feb 2028): Maximum carbon footprint thresholds

    ### Recycled Content Targets
    - **2031**: 16% cobalt, 6% lithium, 6% nickel from recycling
    - **2036**: 26% cobalt, 12% lithium, 15% nickel from recycling

    ### State of Health (SoH) Requirements
    Battery Management Systems must track and report:
    - Remaining capacity vs. original capacity
    - Number of charging cycles
    - Expected remaining useful life
    - Impedance increase
    """

    // MARK: - Machinery Regulation Expertise

    /// Machinery Regulation knowledge
    public static let machineryRegulationExpertise = """
    ## Machinery Regulation Expertise (Regulation 2023/1230)

    ### Transition from Directive
    Replaces Machinery Directive 2006/42/EC:
    - **Effective**: July 2023 (entered into force)
    - **Applicable**: January 20, 2027 (transition period ends)
    - Direct applicability (no national transposition needed)

    ### Key Changes
    1. **Digital instructions**: Manufacturers can provide instructions digitally \
    (paper on request)
    2. **AI safety requirements**: Specific provisions for AI-enabled machinery
    3. **Cybersecurity**: Essential health and safety requirements for security
    4. **Substantial modification**: Clarity on when modifications trigger re-certification

    ### High-Risk Machinery (Annex I)
    Requires third-party conformity assessment:
    - Woodworking and metalworking machinery
    - Press brakes, injection molding machines
    - Underground machinery, vehicles
    - Personal protective equipment
    - Lifting equipment for persons
    - Removable mechanical transmission devices

    ### AI in Machinery
    AI systems used as safety components must:
    - Maintain safe operation even during learning phases
    - Be designed to be supervised
    - Have appropriate risk management for autonomous behavior
    - Comply with EU AI Act for high-risk AI components

    ### CE Marking Requirements
    - Technical documentation (full lifecycle records)
    - Risk assessment (EN ISO 12100 methodology)
    - EU Declaration of Conformity
    - Instructions for use (all life phases)
    """

    // MARK: - Other Compliance Frameworks

    /// RoHS, WEEE, REACH expertise
    public static let complianceFrameworksExpertise = """
    ## Compliance Frameworks Expertise

    ### RoHS Directive (2011/65/EU, as amended)
    Restriction of Hazardous Substances in electrical/electronic equipment:
    - **Lead** (Pb): max 0.1% by weight
    - **Mercury** (Hg): max 0.1%
    - **Cadmium** (Cd): max 0.01%
    - **Hexavalent chromium** (Cr6+): max 0.1%
    - **PBB/PBDE** flame retardants: max 0.1%
    - **DEHP, BBP, DBP, DIBP** phthalates: max 0.1% each

    Exemptions available for specific applications (Annex III/IV).

    ### WEEE Directive (2012/19/EU)
    Waste Electrical and Electronic Equipment:
    - Producer registration and reporting requirements
    - Collection targets (65% of average weight placed on market)
    - Recovery and recycling targets by category
    - Financing of collection and treatment
    - Marking requirements (crossed-out wheeled bin symbol)

    ### REACH Regulation (EC 1907/2006)
    Registration, Evaluation, Authorisation and Restriction of Chemicals:
    - Substances of Very High Concern (SVHC) in Candidate List
    - Authorisation required for Annex XIV substances
    - Restrictions in Annex XVII
    - Communication in supply chain (SDS, 0.1% SVHC notification)

    ### CE Marking (Regulation 765/2008)
    - Indicates conformity with applicable EU legislation
    - Manufacturer's declaration of compliance
    - Required before placing on EU market
    - Must be visible, legible, and indelible
    - Minimum height 5mm (unless otherwise specified)
    """

    // MARK: - Prompt Selection

    /// Detect if a question is about regulations
    /// - Parameter question: The user's question
    /// - Returns: True if the question appears to be regulatory in nature
    public static func isRegulatoryQuestion(_ question: String) -> Bool {
        let lowercased = question.lowercased()

        let regulatoryKeywords = [
            // Regulations
            "espr", "ecodesign", "eu ai act", "ai act", "gdpr",
            "battery regulation", "machinery regulation", "machinery directive",
            "rohs", "weee", "reach", "ce marking", "ce mark",

            // Regulatory concepts
            "regulation", "directive", "compliance", "conformity",
            "mandatory", "requirement", "article", "annex",
            "effective date", "transition period", "enforcement",
            "penalty", "prohibited", "high-risk", "risk tier",

            // DPP specific
            "digital product passport", "dpp", "delegated act",
            "right to repair", "spare parts availability",

            // Battery specific
            "battery passport", "state of health", "soh",
            "recycled content", "carbon footprint declaration",

            // AI specific
            "ai system", "high-risk ai", "prohibited ai",
            "conformity assessment", "technical documentation",

            // General
            "legal", "legally required", "eu law", "european"
        ]

        return regulatoryKeywords.contains { lowercased.contains($0) }
    }

    /// Detect if a question is about AAS/technical standards
    /// - Parameter question: The user's question
    /// - Returns: True if the question is about AAS standards
    public static func isAASQuestion(_ question: String) -> Bool {
        let lowercased = question.lowercased()

        let aasKeywords = [
            "aas", "asset administration shell", "metamodel",
            "submodel", "idta", "aasx", "semantic id",
            "concept description", "submodel element",
            "digital nameplate", "handover documentation",
            "digital twin", "api specification",
            "opc", "open packaging", "relationship"
        ]

        return aasKeywords.contains { lowercased.contains($0) }
    }

    /// Build the appropriate system prompt based on question type
    /// - Parameter question: The user's question
    /// - Returns: Comprehensive system prompt for the question
    public static func buildSystemPrompt(for question: String) -> String {
        var prompt = baseSystemPrompt + "\n\n"

        // Add relevant domain expertise based on question content
        if isRegulatoryQuestion(question) {
            if question.lowercased().contains("ai act") ||
               question.lowercased().contains("ai system") ||
               question.lowercased().contains("high-risk") {
                prompt += euAIActExpertise + "\n\n"
            }

            if question.lowercased().contains("espr") ||
               question.lowercased().contains("ecodesign") ||
               question.lowercased().contains("dpp") ||
               question.lowercased().contains("product passport") {
                prompt += esprExpertise + "\n\n"
                prompt += dppExpertise + "\n\n"
            }

            if question.lowercased().contains("battery") {
                prompt += batteryRegulationExpertise + "\n\n"
            }

            if question.lowercased().contains("machinery") {
                prompt += machineryRegulationExpertise + "\n\n"
            }

            if question.lowercased().contains("rohs") ||
               question.lowercased().contains("weee") ||
               question.lowercased().contains("reach") ||
               question.lowercased().contains("ce mark") {
                prompt += complianceFrameworksExpertise + "\n\n"
            }
        }

        if isAASQuestion(question) {
            prompt += aasExpertise + "\n\n"
        }

        return prompt
    }

    /// Get all domain expertise for comprehensive RAG indexing
    /// - Returns: Combined expertise text for chunking and embedding
    public static func getAllExpertise() -> String {
        return [
            baseSystemPrompt,
            aasExpertise,
            dppExpertise,
            esprExpertise,
            euAIActExpertise,
            batteryRegulationExpertise,
            machineryRegulationExpertise,
            complianceFrameworksExpertise
        ].joined(separator: "\n\n---\n\n")
    }
}
