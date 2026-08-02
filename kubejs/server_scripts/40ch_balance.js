ServerEvents.recipes(event => {
  // Create Deco 2.1.3 ships an invalid 1.21.1 ingredient key for this recipe.
  event.remove({ id: 'createdeco:placard' })
  event.shapeless(
    Item.of('create:placard'),
    ['#createdeco:placards', 'minecraft:white_dye']
  ).id('createdeco:placard')

  // Ender Transmission is retained for rotation and fluid links between
  // Aeronautics/Sable sublevels. Global item teleportation and its chunk
  // loader are outside the Season 1 logistics rules.
  event.remove({ output: 'createendertransmission:item_transmitter' })
  event.remove({ output: 'createendertransmission:chunk_loader' })

  // AP 0.7.62b has an unpriced chunkAnalyze() X-ray that ignores the FE
  // settings below. Keep the peripheral disabled in survival until a binary
  // patch makes chunkAnalyze consume energy.
  event.remove({ output: 'advancedperipherals:geo_scanner' })
  event.remove({ output: 'minecraft:elytra' });
});

PlayerEvents.inventoryChanged(event => {
  const player = event.player

  player.inventory.allItems.forEach(item => {
    if (item.id === 'minecraft:elytra') {
      item.count = 0
    }
  })
});
