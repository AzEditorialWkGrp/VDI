# Personas

## You can choose between 3 Personas:

## Persona 1: Short Form, Online and Fast Turnaround

Producing content for:

News / Sports / Events / Digital / Social Media / Re-versioning

Optimised for creating simpler or fast turnaround edits with 2-3 HD video layers.

Supports realtime playback for gfx overlays, lower thirds, colour correction and video effects.

Content is hosted on an SSD if a single deployment or shared storage if part of a workgroup.

* Resolution: Up to 1920x1080
* Frame-rate: Up to 30fps
* Codecs: ProRes Proxy/LT/422, DNxHD 36/120, XD50, H264
* CPU: 6 Cores
* GPU: 1/2 Tesla M60
* Estimated bandwidth per user: 170 Mbps


 
Virtual Machine: 

* Standard_NV6 instance providing 6 vCPUs, 
* 56GB of RAM
* 340GB of SSD storage
* 1/2 NVIDIA Tesla M60 GPU

Storage: Azure Standard File Storage

## Persona 2: Long Form, Complex Editing and Graphics

Producing content for:

Agencies / Broadcasters / Studios

Optimised for all editing tasks with 3-5 HD video layers and 2 GFX overlays.

Provides realtime playback for complex effects in Premiere and other Adobe CC applications such as After Effects.

Supports 4K editing with correct workflow and format configuration.

Content is hosted on an SSD if a single deployment or shared storage if part of a workgroup.

* Resolution: 1920x1080 to 4K
* Frame-rate: Up to 30fps
* Codecs: ProRes 422/HQ, DNxHD 145/185, DNxHR SQ
* CPU: 12 Cores
* GPU: 1/2 Tesla M60
* Estimated bandwidth per user: 340 Mbps
 
Virtual Machine: 

Standard_NV12s_v3 instance provides:
* 12 vCPUs (equivalent to 6 physical cores)
* 112GB of RAM
* 320GB of temporary SSD storage
* 1/2 NVIDIA Tesla M60 GPU

Storage: Azure Premium File Storage

## Persona 3: Graphics, Compositing, and Finishing

Producing content for:

Graphics / Promos / High-end Advertising / High-end Broadcast

Highest performance machine for compositing, graphics and rendering work when meeting tight deadlines.

Additionally supports 4K, HDR, or 60fps editing with correct workflow and format configuration.

Content is hosted on an SSD if a single deployment or shared storage if part of a workgroup.

* Resolution: 1920x1080 to 4K
* Frame-rate: Up to 60fps
* Codecs: ProRes HQ/4444, DNxHD 185, DNxHR SQ
* CPU: 24 Cores
* GPU: Tesla M60
* Estimated bandwidth per user: 450 Mbps
 
Virtual Machine: 

Standard_NV24s_v3 instance type. The Standard_NV24s_v3 instance provides 
* 24 vCPUs (equivalent to 12 physical cores)
* 224GB of RAM
* 640GB of temporary SSD storage
* 1 x full NVIDIA Tesla M60 GPU

Storage: Azure Premium Files

## Persona Summary

|Persona Name	|Persona	|Resolution	|Codecs	|Estimated disk bandwidth required per simultaneous user	|Azure Instance type	|Azure File Storage	|
|---	|---	|---	|---	|---	|---	|---	|
|Persona1	|Short Form, Online and Fast Turnaround	|Up to 1080i30 (1920X1080)	|XDCAM-50	|170 Mbps	|Standard_NV6	|Standard	|
|Persona2	|Long Form, Complex Editing and Graphics	|Up to 1080i60 (1920X1080)	|DNxHD 145 DNxHR SQ or ProRes 422 ProRes HQ     |340 Mbps	|Standard_NV12s_v3	|Premium	|
|Persona3	|Graphics, Compositing, and Finishing	|Up to 1080i60	|DNxHD 145  DNxHR SQ or ProRes 422 ProRes HQ	|450 Mbps	|Standard_NV24s_v3	|Premium	|

## Instance Size Summary

|Instance Size	|vCPUs	|RAM (GB)	|GPU	|Local temp SSD storage (GB)	|
|---	|---	|---	|---	|---	|
|Standard_NV6	|6	|56	|1/2 NVIDIA Tesla M60	|340	|
|standard_NV12s_v3	|12	|112	|1/2 NVIDIA Tesla M60	|320	|
|Standard_NV24s_v3	|24	|224	|1 NVIDIA Tesla M60	|640	|

# Core Azure Resources deployed :

* App Registration (CAM Service Principal)
* Virtual Machine - Active Directory
* Virtual Machine- Cloud Access Connector
* Azure File Storage (2TB by default- of which only around 40GB is in use.)
* Storage Account- VM boot diagnostics 
* Network Security Group 
* Virtual Network 
* Workstations (max 5)



## Msoft VDI Templates- Infrastructure components- detailed

* Teradici Cloud Access Manager Service
    * Teradici SAAS service- hosted by Teradici
* Teradici Cloud Access Manager Connector
    * Part of Teradici SAAS service- hosted by Teradici
* App Registration (CAM Service Principal)
* Virtual Machine - Active Directory
    * F2 (standard) 
* Virtual Machine- Cloud Access Connector
    * D2s_V3
* Nat Gateway 
* Azure File Storage- dependent on client requirements
    * Standard- 2TiB
    * Premium- 2TiB
* Block block
    * Hot @150GB
* Storage- boot diagnostics 
* Private DNS Zone 
* Network Security Group 
* Virtual Network 
* GitHub Demo Asset repository
* Workstations- dependent on requirements



# Azure File

|Persona Name	|Estimated disk bandwidth required per simultaneous user	|Persona	|Azure File Storage	|
|---	|---	|---	|---	|
|Persona1	|170 Mbps	|News/Sports/Events/Digital	|Standard	|
|Persona2	|340 Mbps	|Advertising/Broadcasters/Studios	|Premium	|
|Persona3	|450 Mbps	|Promos/High-end Advertising	|Premium	|


