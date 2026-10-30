# Home network

Based on `images/network_diagram.py`, with subsequent topology updates.
This diagram has not been checked against the live network.

```mermaid
%%{init: {"theme": "base", "flowchart": {"htmlLabels": false}, "themeVariables": {"fontFamily": "Arial, sans-serif", "primaryTextColor": "#172033", "lineColor": "#64748b", "clusterBkg": "#f8fafc", "clusterBorder": "#94a3b8"}}}%%
flowchart TB
    internet((Internet)) <--> modem["NETGEAR Nighthawk CM1200"]
    modem <--> pfsense
    pfsense <-. Trunk .-> main_switch

    subgraph host["Proxmox host: Dell PowerEdge R520"]
        proxmox["Proxmox"]
        idrac["Dell iDRAC"]
        subgraph guests["Virtual machines and containers"]
            pfsense@{ img: "images/pfsense-logo.png", label: "pfSense", pos: "b", h: 40, constraint: "on" }
            subgraph servers["VLAN 20: Servers"]
                truenas@{ img: "images/truenas_open_storage-logo-full-color-rgb.png", label: "TrueNAS", pos: "b", h: 40, constraint: "on" }
                subgraph kubernetes["Kubernetes cluster: Talos"]
                    kmaster1@{ img: "images/talos_logo.svg", label: "kmaster1", pos: "b", h: 40, constraint: "on" }
                    kmaster2@{ img: "images/talos_logo.svg", label: "kmaster2", pos: "b", h: 40, constraint: "on" }
                    kmaster3@{ img: "images/talos_logo.svg", label: "kmaster3", pos: "b", h: 40, constraint: "on" }
                    kworker1@{ img: "images/talos_logo.svg", label: "kworker1", pos: "b", h: 40, constraint: "on" }
                    kworker2@{ img: "images/talos_logo.svg", label: "kworker2", pos: "b", h: 40, constraint: "on" }
                    kworker3@{ img: "images/talos_logo.svg", label: "kworker3", pos: "b", h: 40, constraint: "on" }
                end
                subgraph containers["LXC"]
                    omada@{ img: "images/omada-logo.svg", label: "Omada Controller", pos: "b", h: 40, constraint: "on" }
                end
            end
        end
    end

    subgraph management["VLAN 10: Management"]
        main_switch["Cisco WS-C3650-48PD"]
        sub_switch["Cisco CBS350"]
        subgraph aps["Wireless access points: TP-Link EAP660 HD V1"]
            ap_living["Living Room"]
            ap_hall["Upstairs Hall"]
            ap_bonus["Bonus Room"]
        end
    end

    main_switch <-. Trunk .-> sub_switch
    main_switch <-. Trunk .-> ap_living & ap_hall & ap_bonus
    main_switch <-->|VLAN 10| idrac
    main_switch <-->|VLAN 10 management| aps
    main_switch <-->|VLAN 0| proxmox
    proxmox <-->|VLAN 20| truenas & omada
    proxmox <-->|VLAN 20| kmaster1 & kmaster2 & kmaster3
    proxmox <-->|VLAN 20| kworker1 & kworker2 & kworker3

    subgraph wired["VLAN 0: Wired clients"]
        lg_bonus["LG C1 TV: Bonus Room"]
        kids_pc["Kidsfun PC"]
        ps4["PlayStation 4"]
    end
    main_switch <-->|VLAN 0| lg_bonus & kids_pc & ps4

    subgraph wireless["VLAN 0: Wireless clients"]
        subgraph mobile["Mobile devices"]
            stephen_phone["Stephen iPhone 18 Pro"]
            becky_phone["Becky iPhone 16 Pro"]
            chris_phone["Chris iPhone 18 Pro"]
            alex_phone["Alex iPhone 16"]
            chris_ipad["Chris iPad"]
            alex_ipad["Alex iPad"]
            sherley_phone["Sherley S23"]
        end
        subgraph entertainment["TV and entertainment"]
            nintendo["Nintendo Switch"]
            sherley_tv["LG TV: Sherley"]
            receiver["Yamaha RX-V683"]
        end
        sherley_pc["Sherley PC"]
        subgraph printers["3D printers"]
            x1c@{ img: "images/bl_logo.png", label: "Bambu Lab X1 Carbon", pos: "b", h: 40, constraint: "on" }
            p1s@{ img: "images/bl_logo.png", label: "Bambu Lab P1S", pos: "b", h: 40, constraint: "on" }
        end
    end
    aps <-->|VLAN 0: Wi-Fi| wireless
    aps <-->|VLAN 0: Wi-Fi| stephen_mac

    subgraph trusted["VLAN 50: Trusted"]
        stephen_pc["Stephen PC"]
        stephen_mac["Stephen MacBook Pro"]
    end
    sub_switch <-->|VLAN 50| stephen_pc & stephen_mac

    classDef wan fill:#e2e8f0,stroke:#475569,color:#172033,stroke-width:2px
    classDef vlan0 fill:#f3e8ff,stroke:#9333ea,color:#581c87,stroke-width:2px
    classDef vlan10 fill:#ffedd5,stroke:#ea580c,color:#7c2d12,stroke-width:2px
    classDef vlan20 fill:#cffafe,stroke:#0891b2,color:#164e63,stroke-width:2px
    classDef vlan50 fill:#dcfce7,stroke:#16a34a,color:#14532d,stroke-width:2px
    classDef firewall fill:#fee2e2,stroke:#dc2626,color:#7f1d1d,stroke-width:2px

    class internet,modem wan
    class pfsense firewall
    class main_switch,sub_switch,ap_living,ap_hall,ap_bonus,idrac vlan10
    class proxmox,lg_bonus,kids_pc,ps4,stephen_phone,becky_phone,chris_phone,alex_phone,chris_ipad,alex_ipad,sherley_phone,nintendo,sherley_tv,receiver,sherley_pc,x1c,p1s vlan0
    class truenas,omada,kmaster1,kmaster2,kmaster3,kworker1,kworker2,kworker3 vlan20
    class stephen_pc,stephen_mac vlan50

    style omada fill:#164e63,stroke:#0891b2,color:#172033,stroke-width:2px
    style host fill:#f8fafc,stroke:#64748b,stroke-width:2px
    style guests fill:#f1f5f9,stroke:#94a3b8
    style management fill:#fff7ed,stroke:#ea580c,stroke-width:2px
    style aps fill:#ffedd5,stroke:#ea580c
    style servers fill:#ecfeff,stroke:#0891b2,stroke-width:2px
    style kubernetes fill:#cffafe,stroke:#0891b2
    style containers fill:#cffafe,stroke:#0891b2
    style wired fill:#faf5ff,stroke:#9333ea,stroke-width:2px
    style wireless fill:#faf5ff,stroke:#9333ea,stroke-width:2px
    style mobile fill:#f3e8ff,stroke:#c084fc
    style entertainment fill:#f3e8ff,stroke:#c084fc
    style printers fill:#f3e8ff,stroke:#c084fc
    style trusted fill:#f0fdf4,stroke:#16a34a,stroke-width:2px

```

- Purple: VLAN 0; orange: VLAN 10 (Management); cyan: VLAN 20 (Servers);
  green: VLAN 50 (Trusted). The firewall is red and the WAN is slate.
- Arrows at both ends indicate bidirectional connectivity. Dashed arrows are trunks;
  solid arrows are VLAN or WAN links. Arrows do not describe firewall rules.
- Wireless clients are grouped under the access points without specifying which AP
  each client currently uses.
- Stephen's MacBook Pro has both a VLAN 0 wireless connection and a VLAN 50
  connection through the CBS350.
- VLAN 30 (IoT) and VLAN 40 (Guest) have no links in this diagram.
- Logos use existing files under `images/`. The Mermaid renderer must support
  image nodes (Mermaid 11.3 or later) and allow loading relative image paths.
- Talos versions are omitted so the diagram does not require Python or a generated
  configuration file to render.

Logo sources: [pfSense (Netgate)](https://www.netgate.com/company/legal/trademarks)
and [Omada (TP-Link)](https://www.tp-link.com/us/landing/new-omada/).
