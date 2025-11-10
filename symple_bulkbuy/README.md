# Symple Bulk Buy

A comprehensive bulk drug dealing system for FiveM servers built with QBCore and ox_lib frameworks. This resource provides an immersive drug dealing experience with GPS navigation, negotiation mechanics, and secure server-side location management.

## ✨ Features

- **📞 Payphone Integration**: Realistic calling system using in-game payphones
- **🗺️ GPS Navigation**: Dynamic waypoints guide players to buyer locations
- **⏰ Time-Based Availability**: Buyers only appear during specific in-game hours
- **💰 Negotiation System**: Counter offers and accept/decline mechanics
- **🚔 Police Alerts**: Random chance of police dispatch during deals
- **🎭 Immersive Animations**: Phone calling, exchange, and negotiation animations
- **🔒 Secure Architecture**: Server-side location validation prevents exploitation
- **📦 Inventory Integration**: Full ox_inventory support with validation
- **🔔 Notification System**: Dual notification support (QBCore + ox_lib)

## 📋 Requirements

- **QBCore Framework**
- **ox_lib**
- **ox_inventory**
- **ox_target**
- **ps-dispatch** (for police alerts)

## 🚀 Installation

1. **Download** the resource to your `resources/[standalone]` directory
2. **Ensure** the resource in your `server.cfg`:
   ```cfg
   ensure symple_bulkbuy
   ```
3. **Configure** item prices and locations in `server.lua` if needed
4. **Restart** your server

## 📍 Configuration

### Payphone Locations
```lua
payphoneLocations = {
    { coords = vector4(69.66, 3760.87, 38.74, 0.85), model = GetHashKey("prop_phonebox_04"), buyerLocationIndex = 1 },
    { coords = vector4(813.36, -2527.26, 39.53, 90.79), model = GetHashKey("prop_phonebox_04"), buyerLocationIndex = 2 },
    { coords = vector4(1141.61, -2049.46, 30.02, 80.06), model = GetHashKey("prop_phonebox_04"), buyerLocationIndex = 3 }
}
```

### Buyer Spawn Locations
```lua
pedSpawnLocations = {
    { coords = vector4(1240.19, -3322.32, 5.03, 242.36), availableTimes = { { start = 15, ["end"] = 24 } } },
    { coords = vector4(473.62, -978.31, 26.98, 353.57), availableTimes = { { start = 8, ["end"] = 18 } } },
    { coords = vector4(-306.32, 6275.25, 30.49, 42.87), availableTimes = { { start = 14, ["end"] = 24 } } },
}
```

### Item Pricing
- **Weed Brick**: $12,000 each
- **Coke Brick**: $18,000 each
- **Cocaine Baggies**: $20 per bag (minimum 500 bags = $10,000)
- **Meth**: $17 per bag (minimum 500 bags = $8,500)

## 🎮 Usage

1. **Approach** a payphone in the game world
2. **Interact** with the payphone to "Make a Call"
3. **Wait** for the buyer to be contacted (with animation)
4. **Follow** the GPS waypoint to the meeting location
5. **Negotiate** with the buyer ped:
   - Accept the initial offer
   - Counter for a 10% higher price (70% success rate)
   - Decline and walk away
6. **Complete** the deal with exchange animations

## 🔧 API Reference

### Client Events
- `symple_bulkbuy:makeCall` - Initiates buyer spawn sequence
- `symple_bulkbuy:startNegotiation` - Opens deal negotiation menu
- `symple_bulkbuy:showNotification` - Displays notifications

### Server Events
- `symple_bulkbuy:completeDeal` - Processes transaction with validation
- `symple_bulkbuy:requestLocations` - Requests location data from server

### Client Functions
- `ShowNotification()` - Unified notification system
- `RemoveBuyerBlip()` - Cleans up blips and waypoints
- `AcceptOffer()` - Handles deal completion
- `IsBuyerAvailableNow()` - Time-based availability check

## 🛡️ Security Features

- **Server-Side Validation**: All location data stored server-side
- **Inventory Verification**: Double-checks item counts before transactions
- **Transaction Rollback**: Money refunded if item removal fails
- **Anti-Exploitation**: Prevents selling more items than owned

## 🎨 Animations Used

- **Phone Calling**: `cellphone@` / `cellphone_call_listen_base`
- **Exchange**: `mp_common` / `givetake1_a` & `givetake1_b`
- **Negotiation**: `misscarsteal4@actor` / `actor_berating_loop` & `car_steal_1_ext_leadin`

## 📝 Notes

- Debug prints are enabled for troubleshooting
- Buyers despawn after 15 minutes of inactivity
- Police alerts have a 30% chance during calls, 40% during deals
- All location data is secured server-side to prevent manipulation

## 🤝 Contributing

Feel free to submit issues, feature requests, or pull requests to improve this resource.

## 📄 License

This resource is provided as-is for use in FiveM servers. Please respect the original author's work and do not redistribute without permission.

---

**Made with ❤️ for the FiveM community**