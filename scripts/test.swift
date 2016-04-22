Go!
Gonna parse the data now ...
['#berries', '#berry-firmnesses', '#berry-flavors', '#characteristics', '#contest-types', '#contest-effects', '#egg-groups', '#encounter-methods', '#encounter-conditions', '#encounter-condition-values', '#evolution-chains', '#evolution-triggers', '#generations', '#genders', '#growth-rates']
berries <h2 id="berries">Berries</h2>
Berries are small fruits that can provide HP and status condition restoration, stat enhancement, and even damage negation when eaten by Pokémon. Check out Bulbapedia for greater detail.
GET api/v2/berry/{id or name}
<h4 id="berry">Berry</h4>
<table>
<thead>
<tr>
<th>Name</th>
<th>Description</th>
<th>Data Type</th>
</tr>
</thead>
<tbody>
<tr>
<td>id</td>
<td>The identifier for this berry resource</td>
<td>integer</td>
</tr>
<tr>
<td>name</td>
<td>The name for this berry resource</td>
<td>string</td>
</tr>
<tr>
<td>growth_time</td>
<td>Time it takes the tree to grow one stage, in hours. Berry trees go through four of these growth stages before they can be picked.</td>
<td>integer</td>
</tr>
<tr>
<td>max_harvest</td>
<td>The maximum number of these berries that can grow on one tree in Generation IV</td>
<td>integer</td>
</tr>
<tr>
<td>natural_gift_power</td>
<td>The power of the move "Natural Gift" when used with this Berry</td>
<td>integer</td>
</tr>
<tr>
<td>size</td>
<td>The size of this Berry, in millimeters</td>
<td>integer</td>
</tr>
<tr>
<td>smoothness</td>
<td>The smoothness of this Berry, used in making Pokéblocks or Poffins</td>
<td>integer</td>
</tr>
<tr>
<td>soil_dryness</td>
<td>The speed at which this Berry dries out the soil as it grows. A higher rate means the soil dries more quickly.</td>
<td>integer</td>
</tr>
<tr>
<td>firmness</td>
<td>The firmness of this berry, used in making Pokéblocks or Poffins</td>
<td><a href="#namedapiresource">NamedAPIResource</a> (<a href="#berry-firmnesses">BerryFirmness</a>)</td>
</tr>
<tr>
<td>flavors</td>
<td>A list of references to each flavor a berry can have and the potency of each of those flavors in regard to this berry</td>
<td>list <a href="#berryflavormap">BerryFlavorMap</a></td>
</tr>
<tr>
<td>item</td>
<td>Berries are actually items. This is a reference to the item specific data for this berry.</td>
<td><a href="#namedapiresource">NamedAPIResource</a> (<a href="#items">Item</a>)</td>
</tr>
<tr>
<td>natural_gift_type</td>
<td>The Type the move "Natural Gift" has when used with this Berry</td>
<td><a href="#namedapiresource">NamedAPIResource</a> (<a href="#types">Type</a>)</td>
</tr>
</tbody>
</table>
Wrote /Users/dkg/Development/private/pokealmanac/PokeAlmanac/scripts/pokeapi.co/pokeapi-generated.swift
Done.
