# 01 — Context Diagram

Who talks to HanseWatt and what it integrates with. Renders natively on GitHub via Mermaid.

```mermaid
flowchart TB
    Lena["👤 Lena (Kundin)<br/>residential customer"]
    Jonas["🧑‍💼 Jonas (Service-Mitarbeiter)<br/>contact-center agent"]
    Petra["👩‍💼 Petra (Teamleiterin)<br/>team lead / analytics"]

    subgraph SF["Salesforce — HanseWatt platform"]
        Agent["🤖 Agentforce Service Agent<br/>(Einstein Trust Layer)"]
        Service["📞 Service Cloud<br/>Case · Knowledge(DE) · Omni-Channel · SLA"]
        Data360["🧠 Data 360 (Data Cloud)<br/>unified profile · Calculated Insights · Segments"]
        EmpAgent["🤝 Employee Agent<br/>case summary · next best action"]
    end

    MDM["🔌 Smart-meter MDM<br/>(simulated)"]
    SAP["🔌 SAP IS-U billing<br/>(simulated)"]
    Channels["💬 Web chat · WhatsApp"]

    Lena --> Channels --> Agent
    Agent --> Service
    Agent --> Data360
    Agent -. escalate .-> EmpAgent
    Jonas --> EmpAgent
    EmpAgent --> Service
    Petra --> Service

    MDM -- Ingestion API --> Data360
    SAP -- MuleSoft / Ingestion --> Data360
    Service -- engagement data --> Data360
    Data360 -- proactive segment --> Service
```

**Reading it:** customers reach the autonomous agent via web/WhatsApp; the agent grounds on
Service Cloud (Knowledge) + Data 360 (unified profile + insights) and acts on records; it
escalates to the employee agent / Jonas; external meter + billing data flows into Data 360,
which closes the loop with proactive segments.

Next: `02-container.md` (planned) — the technical pieces inside the platform.
