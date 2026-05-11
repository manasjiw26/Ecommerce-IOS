delete from products
where name in (
        'Heritage Cast Iron Dutch Oven',
        'Curated Kitchen Tool Collection',
        'Maple Prep Board',
        'Vintage Pantry Spice Rack',
        'Countertop Utensil Crock',
        'Restaurant White Dinnerware Set',
        'Everyday Table Service Set',
        'Traditional Steel Cookware Set',
        'Rustic Linen Table Setting',
        'Nonstick Safe Spatula'
    )
    or image_url ilike 'https://commons.wikimedia.org/wiki/Special:FilePath/%';
